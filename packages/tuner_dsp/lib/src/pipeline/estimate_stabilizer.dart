import 'dart:math' as math;

import '../api/pitch_estimate.dart';

final class EstimateStabilizerConfig {
  const EstimateStabilizerConfig({
    this.minimumClarity = 0.9,
    this.medianWindowSize = 5,
    this.minimumSamples = 2,
    this.emaAlpha = 0.3,
    this.missingFramesBeforeReset = 3,
  }) : assert(minimumClarity >= 0 && minimumClarity <= 1),
       assert(medianWindowSize > 0 && medianWindowSize % 2 == 1),
       assert(minimumSamples > 0 && minimumSamples <= medianWindowSize),
       assert(emaAlpha > 0 && emaAlpha <= 1),
       assert(missingFramesBeforeReset > 0);

  final double minimumClarity;
  final int medianWindowSize;
  final int minimumSamples;
  final double emaAlpha;
  final int missingFramesBeforeReset;
}

final class StabilizedPitchEstimate {
  const StabilizedPitchEstimate({
    required this.frequencyHz,
    required this.clarity,
    required this.sampleCount,
  });

  final double frequencyHz;
  final double clarity;
  final int sampleCount;
}

/// Confidence gate followed by median-of-five and a log-frequency EMA.
///
/// Pitch is filtered in cents so equal musical intervals receive equal weight.
/// Short detection gaps return no value; a longer gap clears stale history.
final class EstimateStabilizer {
  EstimateStabilizer({this.config = const EstimateStabilizerConfig()});

  final EstimateStabilizerConfig config;
  final List<double> _pitchCents = [];
  final List<double> _clarities = [];
  double? _smoothedCents;
  int _missingFrames = 0;

  StabilizedPitchEstimate? add(
    PitchEstimate? estimate, {
    double? minimumClarity,
  }) {
    final clarityFloor = minimumClarity ?? config.minimumClarity;
    assert(clarityFloor >= 0 && clarityFloor <= 1);
    if (!_isTrusted(estimate, clarityFloor)) {
      _missingFrames++;
      if (_missingFrames >= config.missingFramesBeforeReset) {
        reset();
      }
      return null;
    }

    _missingFrames = 0;
    _pitchCents.add(_frequencyToAbsoluteCents(estimate!.frequencyHz));
    _clarities.add(estimate.clarity);
    if (_pitchCents.length > config.medianWindowSize) {
      _pitchCents.removeAt(0);
      _clarities.removeAt(0);
    }
    if (_pitchCents.length < config.minimumSamples) {
      return null;
    }

    final medianCents = _median(_pitchCents);
    final previous = _smoothedCents;
    final smoothed = previous == null
        ? medianCents
        : previous + config.emaAlpha * (medianCents - previous);
    _smoothedCents = smoothed;
    return StabilizedPitchEstimate(
      frequencyHz: math.pow(2, smoothed / 1200).toDouble(),
      clarity: _median(_clarities),
      sampleCount: _pitchCents.length,
    );
  }

  void reset() {
    _pitchCents.clear();
    _clarities.clear();
    _smoothedCents = null;
    _missingFrames = 0;
  }

  bool _isTrusted(PitchEstimate? estimate, double minimumClarity) {
    return estimate != null &&
        estimate.frequencyHz.isFinite &&
        estimate.frequencyHz > 0 &&
        estimate.clarity.isFinite &&
        estimate.clarity >= minimumClarity &&
        estimate.clarity <= 1;
  }
}

double _frequencyToAbsoluteCents(double frequencyHz) {
  return 1200 * math.log(frequencyHz) / math.ln2;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
