import 'dart:typed_data';

import 'audio_capture_config.dart';

/// A running PCM16 capture and the actual platform parameters it selected.
final class AudioCaptureSession {
  const AudioCaptureSession({
    required this.pcm16Bytes,
    required this.actualSampleRate,
    required this.selectedSource,
  });

  final Stream<Uint8List> pcm16Bytes;
  final int actualSampleRate;
  final AudioInputSource selectedSource;
}
