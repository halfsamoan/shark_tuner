/// Platform input source preferences, in fallback order.
enum AudioInputSource { unprocessed, voiceRecognition }

/// Immutable request for a normalized mono PCM capture session.
final class AudioCaptureConfig {
  AudioCaptureConfig({
    this.requestedSampleRate = 48000,
    this.channelCount = 1,
    this.enableAutomaticGainControl = false,
    this.enableEchoCancellation = false,
    this.enableNoiseSuppression = false,
    List<AudioInputSource> sourcePreference = const [
      AudioInputSource.unprocessed,
      AudioInputSource.voiceRecognition,
    ],
  }) : sourcePreference = List.unmodifiable(sourcePreference) {
    if (requestedSampleRate <= 0) {
      throw ArgumentError.value(
        requestedSampleRate,
        'requestedSampleRate',
        'Must be greater than zero.',
      );
    }
    if (channelCount != 1) {
      throw ArgumentError.value(
        channelCount,
        'channelCount',
        'toauner currently accepts mono capture only.',
      );
    }
    if (sourcePreference.isEmpty) {
      throw ArgumentError.value(
        sourcePreference,
        'sourcePreference',
        'At least one source is required.',
      );
    }
  }

  final int requestedSampleRate;
  final int channelCount;
  final bool enableAutomaticGainControl;
  final bool enableEchoCancellation;
  final bool enableNoiseSuppression;
  final List<AudioInputSource> sourcePreference;
}
