import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
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

    test('checks permission without requesting it for UI priming', () async {
      final driver = _FakeRecordStreamDriver(
        permissionGranted: false,
        streams: const {},
      );
      final capture = RecordAudioCapture.withDriver(driver);

      expect(await capture.hasPermission(), isFalse);
      expect(driver.permissionRequests, [false]);
      expect(driver.startedSources, isEmpty);
      await capture.dispose();
    });
  });

  group('tuner record configuration', () {
    test('keeps mobile DSP input unprocessed and interruption-resilient', () {
      final config = buildTunerRecordConfig(
        AudioCaptureConfig.forPlatform(AudioCapturePlatform.ios),
        AudioInputSource.platformDefault,
      );

      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 48000);
      expect(config.numChannels, 1);
      expect(config.autoGain, isFalse);
      expect(config.echoCancel, isFalse);
      expect(config.noiseSuppress, isFalse);
      expect(config.androidConfig.manageBluetooth, isFalse);
      expect(
        config.androidConfig.audioSource,
        AndroidAudioSource.defaultSource,
      );
      expect(config.iosConfig.categoryOptions, isEmpty);
      expect(config.audioInterruption, AudioInterruptionMode.pauseResume);
    });

    test('maps both Android fallback candidates explicitly', () {
      final config = AudioCaptureConfig.forPlatform(
        AudioCapturePlatform.android,
      );

      expect(
        buildTunerRecordConfig(
          config,
          AudioInputSource.unprocessed,
        ).androidConfig.audioSource,
        AndroidAudioSource.unprocessed,
      );
      expect(
        buildTunerRecordConfig(
          config,
          AudioInputSource.voiceRecognition,
        ).androidConfig.audioSource,
        AndroidAudioSource.voiceRecognition,
      );
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
  final permissionRequests = <bool>[];
  var stopCount = 0;

  @override
  Future<bool> hasPermission({bool request = false}) async {
    permissionRequests.add(request);
    return permissionGranted;
  }

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
