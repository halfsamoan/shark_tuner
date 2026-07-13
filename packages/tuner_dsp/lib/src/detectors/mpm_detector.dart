import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../api/pitch_detector.dart';
import '../api/pitch_estimate.dart';
import '../config/tuner_dsp_config.dart';

/// Configuration for the clean-room McLeod Pitch Method implementation.
final class MpmDetectorConfig {
  const MpmDetectorConfig({
    this.minimumFrequencyHz = TunerDspConfig.minimumFrequencyHz,
    this.maximumFrequencyHz = TunerDspConfig.maximumFrequencyHz,
    this.clarityThreshold = 0.8,
    this.peakSelectionThreshold = 0.93,
    this.minimumRms = 1e-5,
  }) : assert(minimumFrequencyHz > 0),
       assert(maximumFrequencyHz > minimumFrequencyHz),
       assert(clarityThreshold >= 0 && clarityThreshold <= 1),
       assert(peakSelectionThreshold > 0 && peakSelectionThreshold <= 1),
       assert(minimumRms >= 0);

  final double minimumFrequencyHz;
  final double maximumFrequencyHz;
  final double clarityThreshold;

  /// Earliest peak at or above this fraction of the strongest peak is chosen.
  final double peakSelectionThreshold;

  final double minimumRms;
}

/// Clean-room MPM detector with FFT-accelerated autocorrelation.
///
/// This implementation follows the normalized square difference function
/// described in the MPM paper. FFT plans and buffers are retained between
/// frames so the default and low-tuning windows avoid quadratic work and
/// repeated plan allocation.
final class MpmDetector implements PitchDetector {
  MpmDetector({this.config = const MpmDetectorConfig()});

  final MpmDetectorConfig config;
  FFT? _fftPlan;
  Float64x2List _fftBuffer = Float64x2List(0);

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

    final centeredSamples = Float64List(samples.length);
    final prefixEnergy = Float64List(samples.length + 1);
    var energy = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final centered = samples[index] - mean;
      centeredSamples[index] = centered;
      energy += centered * centered;
      prefixEnergy[index + 1] = energy;
    }
    final rms = math.sqrt(energy / samples.length);
    if (rms < config.minimumRms) {
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

    // One extra lag is calculated so a boundary candidate can still receive
    // three-point parabolic interpolation.
    final calculationMaxLag = math.min(
      samples.length - 1,
      maximumCandidateLag + 1,
    );
    _calculateAutocorrelation(centeredSamples, calculationMaxLag);
    final nsdf = Float64List(calculationMaxLag + 1);
    for (var lag = 0; lag <= calculationMaxLag; lag++) {
      final overlap = samples.length - lag;
      final squaredMagnitude =
          prefixEnergy[overlap] + (prefixEnergy.last - prefixEnergy[lag]);
      nsdf[lag] = squaredMagnitude == 0
          ? 0
          : (2 * _fftBuffer[lag].x / squaredMagnitude).clamp(-1.0, 1.0);
    }

    final peaks = _positiveLobeMaxima(
      nsdf,
      maximumCandidateLag,
    ).where((index) => index >= minimumLag).toList(growable: false);
    if (peaks.isEmpty) {
      return null;
    }

    var strongestClarity = -1.0;
    for (final peak in peaks) {
      strongestClarity = math.max(strongestClarity, nsdf[peak]);
    }
    final cutoff = math.max(
      config.clarityThreshold,
      strongestClarity * config.peakSelectionThreshold,
    );

    int? selectedPeak;
    for (final peak in peaks) {
      if (nsdf[peak] >= cutoff) {
        selectedPeak = peak;
        break;
      }
    }
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
      clarity: refined.value.clamp(0.0, 1.0),
      periodSamples: refined.periodSamples,
    );
  }

  /// Linear autocorrelation via a zero-padded FFT.
  ///
  /// The zero padding prevents circular wrap for every requested lag. Scratch
  /// buffers are retained by the detector to avoid per-frame GC pressure.
  void _calculateAutocorrelation(Float64List centeredSamples, int maximumLag) {
    var fftSize = 1;
    final requiredSize = centeredSamples.length + maximumLag;
    while (fftSize < requiredSize) {
      fftSize <<= 1;
    }
    if (_fftBuffer.length != fftSize) {
      _fftPlan = FFT(fftSize);
      _fftBuffer = Float64x2List(fftSize);
    } else {
      _fftBuffer.fillRange(0, fftSize, Float64x2.zero());
    }
    for (var index = 0; index < centeredSamples.length; index++) {
      _fftBuffer[index] = Float64x2(centeredSamples[index], 0);
    }
    _fftPlan!.inPlaceFft(_fftBuffer);
    for (var index = 0; index < fftSize; index++) {
      final value = _fftBuffer[index];
      _fftBuffer[index] = Float64x2(value.x * value.x + value.y * value.y, 0);
    }
    _fftPlan!.inPlaceInverseFft(_fftBuffer);
  }

  static List<int> _positiveLobeMaxima(
    Float64List nsdf,
    int maximumCandidateLag,
  ) {
    final peaks = <int>[];
    var cursor = 1;

    // The lobe centered on lag zero represents the trivial self-match.
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

  static ({double periodSamples, double value}) _parabolicPeak(
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

    final offset = (0.5 * (left - right) / curvature).clamp(-1.0, 1.0);
    final value = center - 0.25 * (left - right) * offset;
    return (periodSamples: index + offset, value: value);
  }
}
