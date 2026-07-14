import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tuner_dsp/tuner_dsp.dart';

/// Test-only O(N * lag) MPM reference used to protect the FFT implementation.
///
/// This is intentionally direct and allocation-friendly enough only for a
/// small parity corpus. Production code must use [MpmDetector].
final class TimeDomainMpmReference implements PitchDetector {
  const TimeDomainMpmReference({this.config = const MpmDetectorConfig()});

  final MpmDetectorConfig config;

  @override
  PitchEstimate? detect(Float64List samples, {required double sampleRate}) {
    if (!sampleRate.isFinite || sampleRate <= 0 || samples.length < 4) {
      return null;
    }
    var sum = 0.0;
    for (final sample in samples) {
      if (!sample.isFinite) {
        return null;
      }
      sum += sample;
    }
    final mean = sum / samples.length;
    final centered = Float64List(samples.length);
    var energy = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final value = samples[index] - mean;
      centered[index] = value;
      energy += value * value;
    }
    if (math.sqrt(energy / samples.length) < config.minimumRms) {
      return null;
    }

    final minimumLag = math.max(
      2,
      (sampleRate / config.maximumFrequencyHz).floor(),
    );
    final maximumCandidateLag = math.min(
      samples.length - 2,
      (sampleRate / config.minimumFrequencyHz).floor(),
    );
    if (maximumCandidateLag <= minimumLag) {
      return null;
    }
    final calculationMaxLag = math.min(
      samples.length - 1,
      maximumCandidateLag + 1,
    );
    final nsdf = Float64List(calculationMaxLag + 1);
    for (var lag = 0; lag <= calculationMaxLag; lag++) {
      var correlation = 0.0;
      var squaredMagnitude = 0.0;
      final overlap = samples.length - lag;
      for (var index = 0; index < overlap; index++) {
        final left = centered[index];
        final right = centered[index + lag];
        correlation += left * right;
        squaredMagnitude += left * left + right * right;
      }
      nsdf[lag] = squaredMagnitude == 0
          ? 0
          : (2 * correlation / squaredMagnitude).clamp(-1, 1).toDouble();
    }

    final peaks = _positiveLobeMaxima(nsdf, maximumCandidateLag);
    var strongestClarity = -1.0;
    for (final peak in peaks) {
      if (peak >= minimumLag) {
        strongestClarity = math.max(strongestClarity, nsdf[peak]);
      }
    }
    if (strongestClarity < 0) {
      return null;
    }
    final cutoff = math.max(
      config.clarityThreshold,
      strongestClarity * config.peakSelectionThreshold,
    );
    final selectedPeak = peaks
        .where((peak) => peak >= minimumLag && nsdf[peak] >= cutoff)
        .firstOrNull;
    if (selectedPeak == null) {
      return null;
    }
    final refined = _parabolicPeak(nsdf, selectedPeak);
    if (refined.periodSamples <= 0) {
      return null;
    }
    final frequencyHz = sampleRate / refined.periodSamples;
    if (frequencyHz < config.minimumFrequencyHz ||
        frequencyHz > config.maximumFrequencyHz) {
      return null;
    }
    return PitchEstimate(
      frequencyHz: frequencyHz,
      clarity: refined.value.clamp(0, 1).toDouble(),
      periodSamples: refined.periodSamples,
    );
  }
}

List<int> _positiveLobeMaxima(Float64List nsdf, int maximumCandidateLag) {
  final peaks = <int>[];
  var cursor = 1;
  while (cursor <= maximumCandidateLag && nsdf[cursor] > 0) {
    cursor++;
  }
  while (cursor <= maximumCandidateLag) {
    while (cursor <= maximumCandidateLag && nsdf[cursor] <= 0) {
      cursor++;
    }
    if (cursor > maximumCandidateLag) {
      break;
    }
    var bestIndex = cursor;
    while (cursor <= maximumCandidateLag && nsdf[cursor] > 0) {
      if (nsdf[cursor] > nsdf[bestIndex]) {
        bestIndex = cursor;
      }
      cursor++;
    }
    peaks.add(bestIndex);
  }
  return peaks;
}

({double periodSamples, double value}) _parabolicPeak(
  Float64List values,
  int index,
) {
  if (index <= 0 || index >= values.length - 1) {
    return (periodSamples: index.toDouble(), value: values[index]);
  }
  final left = values[index - 1];
  final center = values[index];
  final right = values[index + 1];
  final curvature = left - 2 * center + right;
  if (curvature.abs() < 1e-12) {
    return (periodSamples: index.toDouble(), value: center);
  }
  final offset = (0.5 * (left - right) / curvature).clamp(-1, 1).toDouble();
  return (
    periodSamples: index + offset,
    value: center - 0.25 * (left - right) * offset,
  );
}
