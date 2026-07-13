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
  Float64List _fftScalars = Float64List(0);
  Float64List _centeredSamples = Float64List(0);
  Float64List _prefixEnergy = Float64List(0);
  Float64List _nsdf = Float64List(0);
  Int32List _peakIndices = Int32List(0);

  @override
  PitchEstimate? detect(Float64List samples, {required double sampleRate}) {
    if (!sampleRate.isFinite || sampleRate <= 0 || samples.length < 4) {
      return null;
    }

    var sum = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      if (!sample.isFinite) {
        return null;
      }
      sum += sample;
    }
    final mean = sum / samples.length;

    _ensureFrameScratch(samples.length);
    var energy = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final centered = samples[index] - mean;
      _centeredSamples[index] = centered;
      energy += centered * centered;
      _prefixEnergy[index + 1] = energy;
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
    _ensureLagScratch(calculationMaxLag + 1);
    _calculateCircularAutocorrelation(_centeredSamples);
    for (var lag = 0; lag <= calculationMaxLag; lag++) {
      final overlap = samples.length - lag;
      var correlation = _fftScalars[lag << 1];
      // An N-point FFT produces circular autocorrelation. Subtract the lag
      // boundary pairs that wrapped around to recover the exact linear
      // autocorrelation used by NSDF, while keeping the FFT half-sized.
      for (var index = overlap; index < samples.length; index++) {
        correlation -=
            _centeredSamples[index] * _centeredSamples[index - overlap];
      }
      final squaredMagnitude =
          _prefixEnergy[overlap] + (energy - _prefixEnergy[lag]);
      _nsdf[lag] = squaredMagnitude == 0
          ? 0
          : (2 * correlation / squaredMagnitude).clamp(-1.0, 1.0);
    }

    final peakCount = _collectPositiveLobeMaxima(
      _nsdf,
      maximumCandidateLag,
      _peakIndices,
    );

    var strongestClarity = -1.0;
    for (var index = 0; index < peakCount; index++) {
      final peak = _peakIndices[index];
      if (peak >= minimumLag) {
        strongestClarity = math.max(strongestClarity, _nsdf[peak]);
      }
    }
    if (strongestClarity < 0) {
      return null;
    }
    final cutoff = math.max(
      config.clarityThreshold,
      strongestClarity * config.peakSelectionThreshold,
    );

    int? selectedPeak;
    for (var index = 0; index < peakCount; index++) {
      final peak = _peakIndices[index];
      if (peak >= minimumLag && _nsdf[peak] >= cutoff) {
        selectedPeak = peak;
        break;
      }
    }
    if (selectedPeak == null) {
      return null;
    }

    final refined = _parabolicPeak(_nsdf, selectedPeak);
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

  void _ensureFrameScratch(int sampleCount) {
    if (_centeredSamples.length != sampleCount) {
      _centeredSamples = Float64List(sampleCount);
      _prefixEnergy = Float64List(sampleCount + 1);
    }
    _prefixEnergy[0] = 0;
  }

  void _ensureLagScratch(int lagCount) {
    if (_nsdf.length < lagCount) {
      _nsdf = Float64List(lagCount);
      _peakIndices = Int32List(lagCount);
    }
  }

  /// Circular autocorrelation via an N-point FFT.
  ///
  /// The caller removes boundary wrap terms for the requested lags to recover
  /// exact linear autocorrelation. Scratch buffers are retained between frames.
  void _calculateCircularAutocorrelation(Float64List centeredSamples) {
    final fftSize = centeredSamples.length;
    if (_fftBuffer.length != fftSize) {
      _fftPlan = FFT(fftSize);
      _fftBuffer = Float64x2List(fftSize);
      _fftScalars = Float64List.view(_fftBuffer.buffer);
    } else {
      _fftScalars.fillRange(0, fftSize << 1, 0);
    }
    for (var index = 0; index < centeredSamples.length; index++) {
      _fftScalars[index << 1] = centeredSamples[index];
    }
    _fftPlan!.inPlaceFft(_fftBuffer);
    for (var index = 0; index < fftSize; index++) {
      final scalarIndex = index << 1;
      final real = _fftScalars[scalarIndex];
      final imaginary = _fftScalars[scalarIndex + 1];
      _fftScalars[scalarIndex] = real * real + imaginary * imaginary;
      _fftScalars[scalarIndex + 1] = 0;
    }
    _fftPlan!.inPlaceInverseFft(_fftBuffer);
  }

  static int _collectPositiveLobeMaxima(
    Float64List nsdf,
    int maximumCandidateLag,
    Int32List peakIndices,
  ) {
    var peakCount = 0;
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
      peakIndices[peakCount++] = bestIndex;
    }

    return peakCount;
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
