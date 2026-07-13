import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:tuner_audio/tuner_audio.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  test(
    'runs PCM capture and MPM stabilization outside the UI isolate',
    () async {
      final capture = _FakeAudioCapture(
        stream: Stream.fromIterable(_sineChunks(frequencyHz: 110)),
      );
      final engine = IsolateTunerEngine(audioCapture: capture);
      final stableState = engine.states.firstWhere(
        (state) => state.frequencyHz != null,
      );

      await engine.start(BuiltInTunings.standardGuitar);
      final state = await stableState.timeout(const Duration(seconds: 5));

      expect(state.status, LiveTunerStatus.listening);
      expect(state.frequencyHz, closeTo(110, 0.1));
      expect(state.target?.stringNumber, 5);
      expect(state.cents, closeTo(0, 1));
      expect(state.actualSampleRate, 48000);
      expect(state.selectedSource, AudioInputSource.unprocessed);
      expect(state.windowSamples, 4096);
      expect(state.hopSamples, 1536);

      await engine.dispose();
      expect(capture.disposed, isTrue);
    },
  );

  test('uses the long window for tunings below E2', () async {
    final capture = _FakeAudioCapture(stream: const Stream.empty());
    final engine = IsolateTunerEngine(audioCapture: capture);
    final lowTuning = TuningDefinition(
      id: 'low',
      version: 1,
      name: 'Low',
      strings: const [
        TuningString(stringNumber: 1, midiNote: 39, label: 'E♭2'),
      ],
    );

    await engine.start(lowTuning);

    expect(engine.current.windowSamples, 8192);
    expect(engine.current.hopSamples, 2304);
    await engine.dispose();
  });

  test('maps microphone denial to an explicit non-listening state', () async {
    final capture = _FakeAudioCapture(
      stream: const Stream.empty(),
      startError: const MicrophonePermissionDeniedException(),
    );
    final engine = IsolateTunerEngine(audioCapture: capture);

    await engine.start(BuiltInTunings.standardGuitar);

    expect(engine.current.status, LiveTunerStatus.permissionDenied);
    expect(engine.current.error, isA<MicrophonePermissionDeniedException>());
    await engine.dispose();
  });
}

List<Uint8List> _sineChunks({required double frequencyHz}) {
  const sampleRate = 48000;
  const sampleCount = 16384;
  const samplesPerChunk = 1024;
  final chunks = <Uint8List>[];
  for (var start = 0; start < sampleCount; start += samplesPerChunk) {
    final bytes = Uint8List(samplesPerChunk * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < samplesPerChunk; index++) {
      final sampleIndex = start + index;
      final normalized =
          0.4 * math.sin(2 * math.pi * frequencyHz * sampleIndex / sampleRate);
      data.setInt16(index * 2, (normalized * 32767).round(), Endian.little);
    }
    chunks.add(bytes);
  }
  return chunks;
}

final class _FakeAudioCapture implements AudioCapture {
  _FakeAudioCapture({required this.stream, this.startError});

  final Stream<Uint8List> stream;
  final Object? startError;
  var _capturing = false;
  var disposed = false;

  @override
  bool get isCapturing => _capturing;

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    _capturing = true;
    return AudioCaptureSession(
      pcm16Bytes: stream,
      actualSampleRate: config.requestedSampleRate,
      selectedSource: AudioInputSource.unprocessed,
    );
  }

  @override
  Future<void> stop() async {
    _capturing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _capturing = false;
  }
}
