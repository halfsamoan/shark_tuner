import 'dart:math' as math;

/// A single fundamental-frequency estimate produced from one analysis window.
final class PitchEstimate {
  const PitchEstimate({
    required this.frequencyHz,
    required this.clarity,
    required this.periodSamples,
  });

  /// Estimated fundamental frequency in hertz.
  final double frequencyHz;

  /// Detector-specific periodicity confidence in the inclusive range 0..1.
  final double clarity;

  /// Refined fundamental period in samples.
  final double periodSamples;

  /// Signed distance from [referenceHz] in equal-tempered cents.
  double centsFrom(double referenceHz) {
    if (!referenceHz.isFinite || referenceHz <= 0) {
      throw ArgumentError.value(
        referenceHz,
        'referenceHz',
        'Must be finite and greater than zero.',
      );
    }
    return 1200 * (math.log(frequencyHz / referenceHz) / math.ln2);
  }
}
