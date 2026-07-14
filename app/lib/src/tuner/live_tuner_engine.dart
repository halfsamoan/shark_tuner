import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tuner_audio/tuner_audio.dart';
import 'package:tuner_domain/tuner_domain.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

enum LiveTunerStatus {
  idle,
  probingInput,
  listening,
  permissionDenied,
  unavailable,
}

final class LiveTunerState {
  const LiveTunerState({
    required this.status,
    this.frequencyHz,
    this.clarity,
    this.rmsDb,
    this.cents,
    this.target,
    this.heardTarget,
    this.locked = false,
    this.lockProgress = 0,
    this.actualSampleRate,
    this.selectedSource,
    this.windowSamples,
    this.hopSamples,
    this.processingDuration,
    this.pluckToFirstValidLatency,
    this.pluckLatencySampleCount = 0,
    this.pluckToDisplayP95Latency,
    this.error,
  });

  static const idle = LiveTunerState(status: LiveTunerStatus.idle);

  final LiveTunerStatus status;
  final double? frequencyHz;
  final double? clarity;
  final double? rmsDb;
  final double? cents;
  final TuningString? target;
  final TuningString? heardTarget;
  final bool locked;
  final double lockProgress;
  final int? actualSampleRate;
  final AudioInputSource? selectedSource;
  final int? windowSamples;
  final int? hopSamples;
  final Duration? processingDuration;
  final Duration? pluckToFirstValidLatency;
  final int pluckLatencySampleCount;
  final Duration? pluckToDisplayP95Latency;
  final Object? error;

  LiveTunerState copyWith({
    LiveTunerStatus? status,
    double? frequencyHz,
    double? clarity,
    double? rmsDb,
    double? cents,
    TuningString? target,
    TuningString? heardTarget,
    bool? locked,
    double? lockProgress,
    int? actualSampleRate,
    AudioInputSource? selectedSource,
    int? windowSamples,
    int? hopSamples,
    Duration? processingDuration,
    Duration? pluckToFirstValidLatency,
    int? pluckLatencySampleCount,
    Duration? pluckToDisplayP95Latency,
    Object? error,
    bool clearPitch = false,
    bool clearHeardTarget = false,
    bool clearError = false,
  }) {
    return LiveTunerState(
      status: status ?? this.status,
      frequencyHz: clearPitch ? null : frequencyHz ?? this.frequencyHz,
      clarity: clearPitch ? null : clarity ?? this.clarity,
      rmsDb: rmsDb ?? this.rmsDb,
      cents: clearPitch ? null : cents ?? this.cents,
      target: clearPitch ? null : target ?? this.target,
      heardTarget: clearPitch || clearHeardTarget
          ? null
          : heardTarget ?? this.heardTarget,
      locked: clearPitch ? false : locked ?? this.locked,
      lockProgress: clearPitch ? 0 : lockProgress ?? this.lockProgress,
      actualSampleRate: actualSampleRate ?? this.actualSampleRate,
      selectedSource: selectedSource ?? this.selectedSource,
      windowSamples: windowSamples ?? this.windowSamples,
      hopSamples: hopSamples ?? this.hopSamples,
      processingDuration: processingDuration ?? this.processingDuration,
      pluckToFirstValidLatency:
          pluckToFirstValidLatency ?? this.pluckToFirstValidLatency,
      pluckLatencySampleCount:
          pluckLatencySampleCount ?? this.pluckLatencySampleCount,
      pluckToDisplayP95Latency:
          pluckToDisplayP95Latency ?? this.pluckToDisplayP95Latency,
      error: clearError ? null : error ?? this.error,
    );
  }
}

abstract interface class TunerEngine {
  LiveTunerState get current;
  Stream<LiveTunerState> get states;

  Future<bool> hasMicrophonePermission();
  Future<void> start(TuningDefinition tuning);
  void setManualTarget(int? stringNumber);
  Future<void> stop();
  Future<void> dispose();
}

typedef TunerEngineFactory = TunerEngine Function();

TunerEngine createLiveTunerEngine() {
  return IsolateTunerEngine(
    audioCapture: RecordAudioCapture(),
    lockConfig: const InTuneLockConfig(
      toleranceCents: 5,
      releaseToleranceCents: 7,
    ),
  );
}

final class IsolateTunerEngine implements TunerEngine {
  IsolateTunerEngine({
    required this._audioCapture,
    this.lockConfig = const InTuneLockConfig(),
  }) : _lockTracker = InTuneLockTracker(config: lockConfig);

  final AudioCapture _audioCapture;
  final InTuneLockConfig lockConfig;
  final _states = StreamController<LiveTunerState>.broadcast();
  final _selector = AutomaticStringSelector();
  final InTuneLockTracker _lockTracker;
  LiveTunerState _current = LiveTunerState.idle;
  TuningDefinition? _tuning;
  int? _manualStringNumber;
  _DspIsolate? _dsp;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, Object?>>? _frameSubscription;
  var _disposed = false;
  int _lastPluckLatencySequence = 0;
  final List<int> _pluckToDisplayLatencyMicros = [];
  int? _heardOtherStringNumber;
  int _heardOtherFrameCount = 0;

  @override
  LiveTunerState get current => _current;

  @override
  Stream<LiveTunerState> get states => _states.stream;

  @override
  Future<bool> hasMicrophonePermission() {
    return _audioCapture.hasPermission();
  }

  @override
  Future<void> start(TuningDefinition tuning) async {
    if (_disposed) {
      throw StateError('Tuner engine has been disposed.');
    }
    if (_current.status != LiveTunerStatus.idle) {
      throw StateError('Tuner engine is already started.');
    }
    _tuning = tuning;
    _selector.reset();
    _lockTracker.reset();
    _manualStringNumber = null;
    _lastPluckLatencySequence = 0;
    _pluckToDisplayLatencyMicros.clear();
    _resetHeardOtherEvidence();
    final windowSamples = _windowSamplesFor(tuning);
    final hopSamples = _hopSamplesFor(windowSamples);
    _emit(
      LiveTunerState(
        status: LiveTunerStatus.probingInput,
        windowSamples: windowSamples,
        hopSamples: hopSamples,
      ),
    );

    try {
      final dsp = await _DspIsolate.spawn();
      _dsp = dsp;
      final session = await _audioCapture.start(AudioCaptureConfig());
      dsp.configure(
        sampleRate: session.actualSampleRate,
        windowSamples: windowSamples,
        hopSamples: hopSamples,
        targetFrequenciesHz: [
          for (final target in tuning.strings)
            target.targetFrequencyHz(
              referenceA4Hz: tuning.referenceA4Hz,
              centsOffset: tuning.centsOffset,
            ),
        ],
      );
      _emit(
        _current.copyWith(
          status: LiveTunerStatus.listening,
          actualSampleRate: session.actualSampleRate,
          selectedSource: session.selectedSource,
          clearPitch: true,
          clearError: true,
        ),
      );
      _frameSubscription = dsp.frames.listen(_handleDspFrame);
      _audioSubscription = session.pcm16Bytes.listen(
        dsp.addAudio,
        onError: (Object error, StackTrace stackTrace) {
          _emit(
            _current.copyWith(
              status: LiveTunerStatus.unavailable,
              error: error,
              clearPitch: true,
            ),
          );
        },
      );
    } on MicrophonePermissionDeniedException catch (error) {
      await _closePipeline();
      _emit(
        _current.copyWith(
          status: LiveTunerStatus.permissionDenied,
          error: error,
          clearPitch: true,
        ),
      );
    } on Object catch (error) {
      await _closePipeline();
      _emit(
        _current.copyWith(
          status: LiveTunerStatus.unavailable,
          error: error,
          clearPitch: true,
        ),
      );
    }
  }

  @override
  void setManualTarget(int? stringNumber) {
    final tuning = _tuning;
    if (stringNumber != null &&
        (tuning == null ||
            !tuning.strings.any(
              (target) => target.stringNumber == stringNumber,
            ))) {
      throw ArgumentError.value(stringNumber, 'stringNumber');
    }
    _manualStringNumber = stringNumber;
    _lockTracker.reset();
    _resetHeardOtherEvidence();
  }

  void _handleDspFrame(Map<String, Object?> frame) {
    if (_current.status != LiveTunerStatus.listening) {
      return;
    }
    final frequencyHz = frame['frequencyHz'] as double?;
    final rmsDb = frame['rmsDb'] as double?;
    final processingMicros = frame['processingMicros'] as int?;
    final pluckLatencyMicros = frame['pluckToFirstValidMicros'] as int?;
    final pluckLatencySequence = frame['pluckLatencySequence'] as int? ?? 0;
    final freshOnset =
        pluckLatencyMicros != null &&
        processingMicros != null &&
        pluckLatencySequence > _lastPluckLatencySequence;
    if (freshOnset) {
      _lastPluckLatencySequence = pluckLatencySequence;
      _pluckToDisplayLatencyMicros.add(pluckLatencyMicros + processingMicros);
    }
    final pluckToDisplayP95 = _durationP95(_pluckToDisplayLatencyMicros);
    if (frequencyHz == null) {
      _lockTracker.reset();
      _resetHeardOtherEvidence();
      _emit(
        _current.copyWith(
          rmsDb: rmsDb,
          processingDuration: processingMicros == null
              ? null
              : Duration(microseconds: processingMicros),
          pluckToFirstValidLatency: pluckLatencyMicros == null
              ? null
              : Duration(microseconds: pluckLatencyMicros),
          pluckLatencySampleCount: _pluckToDisplayLatencyMicros.length,
          pluckToDisplayP95Latency: pluckToDisplayP95,
          clearPitch: true,
        ),
      );
      return;
    }

    final tuning = _tuning!;
    final manualTarget = _manualStringNumber == null
        ? null
        : tuning.strings.singleWhere(
            (target) => target.stringNumber == _manualStringNumber,
          );
    final selection = manualTarget == null
        ? _selector.update(
            frequencyHz: frequencyHz,
            tuning: tuning,
            freshOnset: freshOnset,
          )
        : _selectionFor(frequencyHz, manualTarget, tuning);
    final closest = closestStringSelection(
      frequencyHz: frequencyHz,
      tuning: tuning,
    );
    final heardTarget = _confirmedOtherTarget(
      manualTarget: manualTarget,
      closest: closest?.target,
    );
    if (selection == null) {
      _lockTracker.reset();
      _emit(
        _current.copyWith(
          frequencyHz: frequencyHz,
          clarity: frame['clarity'] as double?,
          rmsDb: rmsDb,
          processingDuration: processingMicros == null
              ? null
              : Duration(microseconds: processingMicros),
          pluckToFirstValidLatency: pluckLatencyMicros == null
              ? null
              : Duration(microseconds: pluckLatencyMicros),
          pluckLatencySampleCount: _pluckToDisplayLatencyMicros.length,
          pluckToDisplayP95Latency: pluckToDisplayP95,
          clearPitch: true,
        ),
      );
      return;
    }
    final audioPositionMicros = frame['audioPositionMicros'] as int;
    final lock = _lockTracker.update(
      cents: selection.cents,
      timestamp: Duration(microseconds: audioPositionMicros),
    );
    _emit(
      _current.copyWith(
        frequencyHz: frequencyHz,
        clarity: frame['clarity'] as double?,
        rmsDb: rmsDb,
        cents: selection.cents,
        target: selection.target,
        heardTarget: heardTarget,
        clearHeardTarget: heardTarget == null,
        locked: lock.locked,
        lockProgress: lock.progress,
        processingDuration: processingMicros == null
            ? null
            : Duration(microseconds: processingMicros),
        pluckToFirstValidLatency: pluckLatencyMicros == null
            ? null
            : Duration(microseconds: pluckLatencyMicros),
        pluckLatencySampleCount: _pluckToDisplayLatencyMicros.length,
        pluckToDisplayP95Latency: pluckToDisplayP95,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _closePipeline();
    _selector.reset();
    _lockTracker.reset();
    _tuning = null;
    _manualStringNumber = null;
    _resetHeardOtherEvidence();
    _emit(LiveTunerState.idle);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await _closePipeline();
    _disposed = true;
    await _audioCapture.dispose();
    await _states.close();
  }

  Future<void> _closePipeline() async {
    final audioSubscription = _audioSubscription;
    final frameSubscription = _frameSubscription;
    final dsp = _dsp;
    _audioSubscription = null;
    _frameSubscription = null;
    _dsp = null;
    await audioSubscription?.cancel();
    await frameSubscription?.cancel();
    dsp?.close();
    if (_audioCapture.isCapturing) {
      await _audioCapture.stop();
    }
  }

  void _emit(LiveTunerState state) {
    _current = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  TuningString? _confirmedOtherTarget({
    required TuningString? manualTarget,
    required TuningString? closest,
  }) {
    if (manualTarget == null ||
        closest == null ||
        closest.stringNumber == manualTarget.stringNumber) {
      _resetHeardOtherEvidence();
      return null;
    }
    if (_heardOtherStringNumber == closest.stringNumber) {
      _heardOtherFrameCount++;
    } else {
      _heardOtherStringNumber = closest.stringNumber;
      _heardOtherFrameCount = 1;
    }
    return _heardOtherFrameCount >= 2 ? closest : null;
  }

  void _resetHeardOtherEvidence() {
    _heardOtherStringNumber = null;
    _heardOtherFrameCount = 0;
  }
}

StringSelection _selectionFor(
  double frequencyHz,
  TuningString target,
  TuningDefinition tuning,
) {
  final targetHz = target.targetFrequencyHz(
    referenceA4Hz: tuning.referenceA4Hz,
    centsOffset: tuning.centsOffset,
  );
  final cents = 1200 * math.log(frequencyHz / targetHz) / math.ln2;
  return StringSelection(
    target: target,
    targetFrequencyHz: targetHz,
    cents: cents,
  );
}

int _windowSamplesFor(TuningDefinition tuning) {
  final lowestFrequency = tuning.strings
      .map(
        (target) => target.targetFrequencyHz(
          referenceA4Hz: tuning.referenceA4Hz,
          centsOffset: tuning.centsOffset,
        ),
      )
      .reduce(math.min);
  return lowestFrequency < 80
      ? TunerDspConfig.lowTuningWindowSize
      : TunerDspConfig.standardWindowSize;
}

int _hopSamplesFor(int windowSamples) {
  return windowSamples == TunerDspConfig.lowTuningWindowSize
      ? TunerDspConfig.lowTuningHopSize
      : TunerDspConfig.hopSize;
}

final class _DspIsolate {
  _DspIsolate._({
    required this.frames,
    required this._commands,
    required this._isolate,
    required this._framePort,
  });

  final Stream<Map<String, Object?>> frames;
  final SendPort _commands;
  final Isolate _isolate;
  final ReceivePort _framePort;
  var _closed = false;

  static Future<_DspIsolate> spawn() async {
    final readyPort = ReceivePort();
    final framePort = ReceivePort();
    final isolate = await Isolate.spawn(_dspIsolateMain, <String, Object>{
      'readyPort': readyPort.sendPort,
      'framePort': framePort.sendPort,
    }, debugName: 'toauner-dsp');
    final commands = await readyPort.first as SendPort;
    readyPort.close();
    return _DspIsolate._(
      frames: framePort.cast<Map<String, Object?>>(),
      commands: commands,
      isolate: isolate,
      framePort: framePort,
    );
  }

  void configure({
    required int sampleRate,
    required int windowSamples,
    required int hopSamples,
    required List<double> targetFrequenciesHz,
  }) {
    final minimumTargetHz = targetFrequenciesHz.reduce(math.min);
    final sessionMinimumFrequencyHz = math.max(
      TunerDspConfig.minimumFrequencyHz,
      minimumTargetHz / math.pow(2, 3 / 12),
    );
    _commands.send({
      'type': 'configure',
      'sampleRate': sampleRate,
      'windowSamples': windowSamples,
      'hopSamples': hopSamples,
      'targetFrequenciesHz': targetFrequenciesHz,
      'minimumFrequencyHz': sessionMinimumFrequencyHz,
    });
  }

  void addAudio(Uint8List bytes) {
    if (_closed || bytes.isEmpty) {
      return;
    }
    _commands.send({
      'type': 'audio',
      'bytes': TransferableTypedData.fromList([bytes]),
    });
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _commands.send(const {'type': 'close'});
    _framePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

void _dspIsolateMain(Map<String, Object> bootstrap) {
  final readyPort = bootstrap['readyPort']! as SendPort;
  final framePort = bootstrap['framePort']! as SendPort;
  final commands = ReceivePort();
  readyPort.send(commands.sendPort);

  SampleRingBuffer? ring;
  PitchTrackingPipeline? pitchPipeline;
  int? sampleRate;
  int? windowSamples;
  var hopSamples = TunerDspConfig.hopSize;
  var samplesUntilAnalysis = 0;
  var processedSamples = 0;
  int? pendingLowByte;
  int? pluckToFirstValidMicros;
  int? pendingPluckOnsetSample;
  var pluckLatencySequence = 0;
  var detector = MpmDetector();
  PluckOnsetTracker? onsetTracker;

  void analyzeFrame() {
    final activeRing = ring!;
    final activeWindow = windowSamples!;
    final activeSampleRate = sampleRate!;
    final samples = activeRing.copyLatest(activeWindow);
    var sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / samples.length);
    final rmsDb = rms == 0
        ? double.negativeInfinity
        : 20 * math.log(rms) / math.ln10;
    final stopwatch = Stopwatch()..start();
    final raw = detector.detect(
      samples,
      sampleRate: activeSampleRate.toDouble(),
    );
    final tracked = pitchPipeline!.process(raw);
    final stable = tracked.stabilized;
    if (stable != null) {
      final onset = pendingPluckOnsetSample;
      if (onset != null) {
        final latencySamples = processedSamples - onset;
        if (latencySamples >= 0 && latencySamples <= activeSampleRate ~/ 2) {
          pluckToFirstValidMicros =
              (latencySamples * Duration.microsecondsPerSecond) ~/
              activeSampleRate;
          pluckLatencySequence++;
        }
        pendingPluckOnsetSample = null;
      }
    }
    stopwatch.stop();
    framePort.send(<String, Object?>{
      'frequencyHz': stable?.frequencyHz,
      'clarity': stable?.clarity ?? raw?.clarity,
      'rawFrequencyHz': raw?.frequencyHz,
      'confidenceAccepted': tracked.confidenceAccepted,
      'octaveCorrection': tracked.octaveSanity?.kind.name,
      'rmsDb': rmsDb,
      'audioPositionMicros':
          (processedSamples * Duration.microsecondsPerSecond) ~/
          activeSampleRate,
      'processingMicros': stopwatch.elapsedMicroseconds,
      'pluckToFirstValidMicros': pluckToFirstValidMicros,
      'pluckLatencySequence': pluckLatencySequence,
    });
  }

  void addSingleSample(int unsignedSample) {
    final signedSample = unsignedSample >= 0x8000
        ? unsignedSample - 0x10000
        : unsignedSample;
    final normalized = signedSample / 32768.0;
    final onset = onsetTracker!.addSample(normalized);
    if (onset != null) {
      pendingPluckOnsetSample = onset;
      pitchPipeline!.reset();
    }
    ring!.write(normalized);
    processedSamples++;
    samplesUntilAnalysis--;
    if (samplesUntilAnalysis <= 0 && ring!.length >= windowSamples!) {
      analyzeFrame();
      samplesUntilAnalysis = hopSamples;
    }
  }

  commands.listen((message) {
    final command = message! as Map<Object?, Object?>;
    switch (command['type']) {
      case 'configure':
        sampleRate = command['sampleRate']! as int;
        windowSamples = command['windowSamples']! as int;
        hopSamples = command['hopSamples']! as int;
        ring = SampleRingBuffer(TunerDspConfig.ringBufferCapacity);
        pitchPipeline = PitchTrackingPipeline(
          targetFrequenciesHz: (command['targetFrequenciesHz']! as List)
              .cast<double>(),
        );
        detector = MpmDetector(
          config: MpmDetectorConfig(
            minimumFrequencyHz: command['minimumFrequencyHz']! as double,
          ),
        );
        onsetTracker = PluckOnsetTracker(sampleRateHz: sampleRate!);
        samplesUntilAnalysis = windowSamples!;
        processedSamples = 0;
        pendingLowByte = null;
        pluckToFirstValidMicros = null;
        pendingPluckOnsetSample = null;
        pluckLatencySequence = 0;
      case 'audio':
        if (ring == null) {
          return;
        }
        final transferable = command['bytes']! as TransferableTypedData;
        final bytes = transferable.materialize().asUint8List();
        var index = 0;
        final lowByte = pendingLowByte;
        if (lowByte != null && bytes.isNotEmpty) {
          addSingleSample(lowByte | (bytes[0] << 8));
          pendingLowByte = null;
          index = 1;
        }
        while (index + 1 < bytes.length) {
          final availableSamples = (bytes.length - index) >> 1;
          final batchSamples = math.min(availableSamples, samplesUntilAnalysis);
          final batchEnd = index + (batchSamples << 1);
          final onsets = onsetTracker!.addPcm16Le(
            bytes,
            start: index,
            end: batchEnd,
          );
          if (onsets.isNotEmpty) {
            pendingPluckOnsetSample = onsets.last;
            pitchPipeline!.reset();
          }
          ring!.writePcm16Le(bytes, start: index, end: batchEnd);
          processedSamples += batchSamples;
          samplesUntilAnalysis -= batchSamples;
          index = batchEnd;
          if (samplesUntilAnalysis == 0 && ring!.length >= windowSamples!) {
            analyzeFrame();
            samplesUntilAnalysis = hopSamples;
          }
        }
        if (index < bytes.length) {
          pendingLowByte = bytes[index];
        }
      case 'close':
        commands.close();
    }
  });
}

Duration? _durationP95(List<int> values) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = [...values]..sort();
  final rank = (0.95 * sorted.length).ceil().clamp(1, sorted.length);
  return Duration(microseconds: sorted[rank - 1]);
}
