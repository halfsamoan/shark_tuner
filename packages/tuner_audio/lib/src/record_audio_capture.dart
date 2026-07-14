import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio_capture.dart';
import 'audio_capture_config.dart';
import 'audio_capture_session.dart';
import 'record_stream_driver.dart';

final class MicrophonePermissionDeniedException implements Exception {
  const MicrophonePermissionDeniedException();

  @override
  String toString() => 'Microphone permission was denied.';
}

final class AudioCaptureUnavailableException implements Exception {
  const AudioCaptureUnavailableException(this.lastError);

  final Object? lastError;

  @override
  String toString() => lastError == null
      ? 'No configured audio source produced a usable PCM stream.'
      : 'No configured audio source produced a usable PCM stream: $lastError';
}

/// `record` package implementation with the required Android source fallback.
///
/// Each candidate source must produce a short, non-silent PCM16 probe before it
/// is exposed to the DSP pipeline. This catches the known all-zero
/// `UNPROCESSED` behavior on some devices and retries with voice recognition.
final class RecordAudioCapture implements AudioCapture {
  factory RecordAudioCapture({
    int sanityProbeSamples = 4800,
    double minimumRmsDb = -90,
    Duration probeTimeout = const Duration(seconds: 1),
  }) {
    return RecordAudioCapture.withDriver(
      RecordPackageStreamDriver(AudioRecorder()),
      sanityProbeSamples: sanityProbeSamples,
      minimumRmsDb: minimumRmsDb,
      probeTimeout: probeTimeout,
    );
  }

  RecordAudioCapture.withDriver(
    this._driver, {
    this.sanityProbeSamples = 4800,
    this.minimumRmsDb = -90,
    this.probeTimeout = const Duration(seconds: 1),
  }) {
    if (sanityProbeSamples <= 0) {
      throw ArgumentError.value(sanityProbeSamples, 'sanityProbeSamples');
    }
    if (!minimumRmsDb.isFinite || minimumRmsDb >= 0) {
      throw ArgumentError.value(minimumRmsDb, 'minimumRmsDb');
    }
    if (probeTimeout <= Duration.zero) {
      throw ArgumentError.value(probeTimeout, 'probeTimeout');
    }
  }

  final RecordStreamDriver _driver;
  final int sanityProbeSamples;
  final double minimumRmsDb;
  final Duration probeTimeout;

  StreamSubscription<Uint8List>? _subscription;
  StreamController<Uint8List>? _controller;
  var _isCapturing = false;
  var _isDisposed = false;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<bool> hasPermission({bool request = false}) {
    if (_isDisposed) {
      throw StateError('Audio capture has been disposed.');
    }
    return _driver.hasPermission(request: request);
  }

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async {
    if (_isDisposed) {
      throw StateError('Audio capture has been disposed.');
    }
    if (_isCapturing) {
      throw StateError('Audio capture is already running.');
    }
    if (!await _driver.hasPermission(request: true)) {
      throw const MicrophonePermissionDeniedException();
    }

    Object? lastError;
    for (final source in config.sourcePreference) {
      StreamSubscription<Uint8List>? candidateSubscription;
      StreamController<Uint8List>? candidateController;
      try {
        final driverStream = await _driver.start(config, source);
        candidateController = StreamController<Uint8List>();
        final probe = Pcm16SanityProbe(
          targetSamples: sanityProbeSamples,
          minimumRmsDb: minimumRmsDb,
        );
        candidateSubscription = driverStream.bytes.listen(
          (chunk) {
            probe.add(chunk);
            candidateController?.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            lastError = error;
            probe.fail();
            candidateController?.addError(error, stackTrace);
          },
          onDone: () {
            probe.finish();
            if (candidateController?.isClosed == false) {
              unawaited(candidateController?.close());
            }
          },
        );

        final isUsable = await probe.result.timeout(
          probeTimeout,
          onTimeout: () => false,
        );
        if (!isUsable) {
          await candidateSubscription.cancel();
          if (!candidateController.isClosed) {
            unawaited(candidateController.close());
          }
          await _stopDriverIgnoringErrors();
          continue;
        }

        final actualSampleRate = driverStream.actualSampleRate;
        if (actualSampleRate <= 0) {
          throw StateError('Recorder returned an invalid sample rate.');
        }

        _subscription = candidateSubscription;
        _controller = candidateController;
        _isCapturing = true;
        return AudioCaptureSession(
          pcm16Bytes: candidateController.stream,
          actualSampleRate: actualSampleRate,
          selectedSource: source,
        );
      } catch (error) {
        lastError = error;
        await candidateSubscription?.cancel();
        if (candidateController?.isClosed == false) {
          unawaited(candidateController?.close());
        }
        await _stopDriverIgnoringErrors();
      }
    }

    throw AudioCaptureUnavailableException(lastError);
  }

  @override
  Future<void> stop() async {
    final subscription = _subscription;
    final controller = _controller;
    _subscription = null;
    _controller = null;
    _isCapturing = false;

    await subscription?.cancel();
    await _driver.stop();
    if (controller?.isClosed == false) {
      unawaited(controller?.close());
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    if (_isCapturing) {
      await stop();
    }
    _isDisposed = true;
    await _driver.dispose();
  }

  Future<void> _stopDriverIgnoringErrors() async {
    try {
      await _driver.stop();
    } on Object {
      // Preserve the source/probe error that caused the fallback.
    }
  }
}

/// Stateful PCM16 little-endian probe used by the capture fallback policy.
final class Pcm16SanityProbe {
  Pcm16SanityProbe({required this.targetSamples, required this.minimumRmsDb});

  final int targetSamples;
  final double minimumRmsDb;
  final _completer = Completer<bool>();
  var _sampleCount = 0;
  var _nonZeroSampleCount = 0;
  var _sumSquares = 0.0;
  int? _pendingLowByte;

  Future<bool> get result => _completer.future;

  void add(Uint8List bytes) {
    if (_completer.isCompleted) {
      return;
    }
    var index = 0;
    if (_pendingLowByte case final lowByte?) {
      if (bytes.isNotEmpty) {
        _addSample(lowByte | (bytes[0] << 8));
        _pendingLowByte = null;
        index = 1;
      }
    }

    while (index + 1 < bytes.length && !_completer.isCompleted) {
      _addSample(bytes[index] | (bytes[index + 1] << 8));
      index += 2;
    }
    if (index < bytes.length && !_completer.isCompleted) {
      _pendingLowByte = bytes[index];
    }
  }

  void finish() {
    if (!_completer.isCompleted) {
      _completer.complete(_evaluate());
    }
  }

  void fail() {
    if (!_completer.isCompleted) {
      _completer.complete(false);
    }
  }

  void _addSample(int unsignedSample) {
    final signedSample = unsignedSample >= 0x8000
        ? unsignedSample - 0x10000
        : unsignedSample;
    if (signedSample != 0) {
      _nonZeroSampleCount++;
    }
    final normalized = signedSample / 32768.0;
    _sumSquares += normalized * normalized;
    _sampleCount++;
    if (_sampleCount >= targetSamples && !_completer.isCompleted) {
      _completer.complete(_evaluate());
    }
  }

  bool _evaluate() {
    if (_sampleCount == 0) {
      return false;
    }
    final minimumNonZeroSamples = math.max(4, _sampleCount ~/ 1000);
    if (_nonZeroSampleCount < minimumNonZeroSamples) {
      return false;
    }
    final rms = math.sqrt(_sumSquares / _sampleCount);
    final rmsDb = rms == 0
        ? double.negativeInfinity
        : 20 * math.log(rms) / math.ln10;
    return rmsDb >= minimumRmsDb;
  }
}

final class RecordPackageStreamDriver implements RecordStreamDriver {
  RecordPackageStreamDriver(this._recorder);

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission({bool request = false}) {
    return _recorder.hasPermission(request: request);
  }

  @override
  Future<RecordDriverStream> start(
    AudioCaptureConfig config,
    AudioInputSource source,
  ) async {
    var actualSampleRate = config.requestedSampleRate;
    await _recorder.setOnConfigChanged((adjusted) {
      actualSampleRate = adjusted.sampleRate;
    });
    final recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: config.requestedSampleRate,
      numChannels: config.channelCount,
      autoGain: config.enableAutomaticGainControl,
      echoCancel: config.enableEchoCancellation,
      noiseSuppress: config.enableNoiseSuppression,
      androidConfig: AndroidRecordConfig(
        manageBluetooth: false,
        audioSource: switch (source) {
          AudioInputSource.unprocessed => AndroidAudioSource.unprocessed,
          AudioInputSource.voiceRecognition =>
            AndroidAudioSource.voiceRecognition,
        },
      ),
    );
    final bytes = await _recorder.startStream(recordConfig);
    return RecordDriverStream(
      bytes: bytes,
      actualSampleRateProvider: () => actualSampleRate,
    );
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
    await _recorder.setOnConfigChanged(null);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
