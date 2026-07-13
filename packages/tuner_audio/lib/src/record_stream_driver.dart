import 'dart:typed_data';

import 'audio_capture_config.dart';

/// Low-level adapter used to isolate the third-party recorder from our policy.
abstract interface class RecordStreamDriver {
  Future<bool> hasPermission();

  Future<RecordDriverStream> start(
    AudioCaptureConfig config,
    AudioInputSource source,
  );

  Future<void> stop();

  Future<void> dispose();
}

final class RecordDriverStream {
  RecordDriverStream({
    required this.bytes,
    required this.actualSampleRateProvider,
  });

  final Stream<Uint8List> bytes;
  final int Function() actualSampleRateProvider;

  int get actualSampleRate => actualSampleRateProvider();
}
