import 'audio_capture_config.dart';
import 'audio_capture_session.dart';

/// Stable seam between the tuner pipeline and platform audio implementations.
abstract interface class AudioCapture {
  bool get isCapturing;

  /// Checks microphone permission without prompting unless [request] is true.
  Future<bool> hasPermission({bool request = false});

  Future<AudioCaptureSession> start(AudioCaptureConfig config);

  Future<void> stop();

  Future<void> dispose();
}
