import 'dart:typed_data';

import 'pitch_estimate.dart';

/// Stable seam between the app pipeline and replaceable pitch algorithms.
abstract interface class PitchDetector {
  /// Returns `null` when the window cannot support a trustworthy estimate.
  PitchEstimate? detect(Float64List samples, {required double sampleRate});
}
