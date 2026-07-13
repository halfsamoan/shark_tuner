import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuner_audio/src/record_stream_driver.dart';
import 'package:tuner_audio/tuner_audio.dart';

void main() {
  group('RecordAudioCapture', () {
    test('falls back when unprocessed produces digital silence', () async {
      final driver = _FakeRecordStreamDriver(
        streams: {
          AudioInputSource.unprocessed: _pcmStream(amplitude: 0),
          AudioInputSource.voiceRecognition: _pcmStream(amplitude: 0.2),
        },
      );
      final capture = RecordAudioCapture.withDriver(
        driver,
        sanityProbeSamples: 256,
      );

      final session = await capture.start(AudioCaptureConfig());

      expect(session.selectedSource, AudioInputSource.voiceRecognition);
      expect(session.actualSampleRate, 48000);
      expect(driver.startedSources, [
        AudioInputSource.unprocessed,
        AudioInputSource.voiceRecognition,
      ]);
      expect(driver.stopCount, 1);
      await capture.stop();
      await capture.dispose();
    });

    test('keeps unprocessed when its probe contains a usable signal', () async {
      final driver = _FakeRecordStreamDriver(
        streams: {AudioInputSource.unprocessed: _pcmStream(amplitude: 0.1)},
      );
      final capture = RecordAudioCapture.withDriver(
        driver,
        sanityProbeSamples: 256,
      );

      final session = await capture.start(AudioCaptureConfig());

      expect(session.selectedSource, AudioInputSource.unprocessed);
      expect(driver.startedSources, [AudioInputSource.unprocessed]);
      await capture.stop();
      await capture.dispose();
    });

    test('does not start a driver when permission is denied', () async {
      final driver = _FakeRecordStreamDriver(
        permissionGranted: false,
        streams: const {},
      );
      final capture = RecordAudioCapture.withDriver(driver);

      await expectLater(
        capture.start(AudioCaptureConfig()),
        throwsA(isA<MicrophonePermissionDeniedException>()),
      );
      expect(driver.startedSources, isEmpty);
      await capture.dispose();
    });
  });
}

Stream<Uint8List> _pcmStream({required double amplitude}) {
  final bytes = Uint8List(2048);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < bytes.length ~/ 2; index++) {
    final sample = (amplitude * 32767 * math.sin(2 * math.pi * index / 32))
        .round();
    data.setInt16(index * 2, sample, Endian.little);
  }
  return Stream.fromIterable([bytes]);
}

final class _FakeRecordStreamDriver implements RecordStreamDriver {
  _FakeRecordStreamDriver({
    required this.streams,
    this.permissionGranted = true,
  });

  final bool permissionGranted;
  final Map<AudioInputSource, Stream<Uint8List>> streams;
  final startedSources = <AudioInputSource>[];
  var stopCount = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<RecordDriverStream> start(
    AudioCaptureConfig config,
    AudioInputSource source,
  ) async {
    startedSources.add(source);
    final stream = streams[source];
    if (stream == null) {
      throw StateError('No fake stream for $source');
    }
    return RecordDriverStream(
      bytes: stream,
      actualSampleRateProvider: () => config.requestedSampleRate,
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {}
}
