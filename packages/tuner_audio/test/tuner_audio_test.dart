import 'package:flutter_test/flutter_test.dart';
import 'package:tuner_audio/tuner_audio.dart';

void main() {
  test('defaults to the required unprocessed fallback chain', () {
    final config = AudioCaptureConfig();

    expect(config.requestedSampleRate, 48000);
    expect(config.channelCount, 1);
    expect(config.enableAutomaticGainControl, isFalse);
    expect(config.enableEchoCancellation, isFalse);
    expect(config.enableNoiseSuppression, isFalse);
    expect(config.sourcePreference, [
      AudioInputSource.unprocessed,
      AudioInputSource.voiceRecognition,
    ]);
  });

  test('source preference cannot be changed after construction', () {
    final config = AudioCaptureConfig();

    expect(
      () => config.sourcePreference.add(AudioInputSource.unprocessed),
      throwsUnsupportedError,
    );
  });
}
