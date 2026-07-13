/// Shared defaults that define toauner's supported DSP operating envelope.
abstract final class TunerDspConfig {
  static const double sampleRateHz = 48000;
  static const double minimumFrequencyHz = 43;
  // The detector keeps modest headroom above the current 1,318 Hz S1 corpus
  // so interpolation at the corpus boundary is not rejected as out of range.
  static const double maximumFrequencyHz = 1500;
  static const double highPassCutoffHz = 30;

  static const int standardWindowSize = 4096;
  static const int lowTuningWindowSize = 8192;
  static const int hopSize = 1536;
  static const int ringBufferCapacity = 32768;
}
