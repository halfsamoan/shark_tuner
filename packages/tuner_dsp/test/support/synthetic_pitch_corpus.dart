import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tuner_dsp/tuner_dsp.dart';

final class SyntheticAccuracyThresholds {
  const SyntheticAccuracyThresholds({
    this.maximumMedianAbsoluteErrorCents = 0.5,
    this.maximumP95AbsoluteErrorCents = 1,
    this.maximumAbsoluteErrorCents = 1,
    this.maximumOctaveErrorRate = 0,
    this.maximumNoEstimateCount = 0,
  });

  final double maximumMedianAbsoluteErrorCents;
  final double maximumP95AbsoluteErrorCents;
  final double maximumAbsoluteErrorCents;
  final double maximumOctaveErrorRate;
  final int maximumNoEstimateCount;

  Map<String, Object> toJson() => {
    'maximumMedianAbsoluteErrorCents': maximumMedianAbsoluteErrorCents,
    'maximumP95AbsoluteErrorCents': maximumP95AbsoluteErrorCents,
    'maximumAbsoluteErrorCents': maximumAbsoluteErrorCents,
    'maximumOctaveErrorRate': maximumOctaveErrorRate,
    'maximumNoEstimateCount': maximumNoEstimateCount,
  };
}

final class SyntheticAccuracyResult {
  const SyntheticAccuracyResult({
    required this.windowSamples,
    required this.inputCount,
    required this.estimateCount,
    required this.noEstimateCount,
    required this.medianAbsoluteErrorCents,
    required this.p95AbsoluteErrorCents,
    required this.maximumAbsoluteErrorCents,
    required this.octaveErrorCount,
    required this.elapsedMilliseconds,
    required this.thresholds,
  });

  final int windowSamples;
  final int inputCount;
  final int estimateCount;
  final int noEstimateCount;
  final double? medianAbsoluteErrorCents;
  final double? p95AbsoluteErrorCents;
  final double? maximumAbsoluteErrorCents;
  final int octaveErrorCount;
  final int elapsedMilliseconds;
  final SyntheticAccuracyThresholds thresholds;

  double get octaveErrorRate =>
      estimateCount == 0 ? 0 : octaveErrorCount / estimateCount;

  List<String> get violations {
    final violations = <String>[];
    final median = medianAbsoluteErrorCents;
    final p95 = p95AbsoluteErrorCents;
    final maximum = maximumAbsoluteErrorCents;
    if (noEstimateCount > thresholds.maximumNoEstimateCount) {
      violations.add(
        'noEstimateCount=$noEstimateCount > '
        '${thresholds.maximumNoEstimateCount}',
      );
    }
    if (median == null || median > thresholds.maximumMedianAbsoluteErrorCents) {
      violations.add(
        'medianAbsoluteErrorCents=$median > '
        '${thresholds.maximumMedianAbsoluteErrorCents}',
      );
    }
    if (p95 == null || p95 > thresholds.maximumP95AbsoluteErrorCents) {
      violations.add(
        'p95AbsoluteErrorCents=$p95 > '
        '${thresholds.maximumP95AbsoluteErrorCents}',
      );
    }
    if (maximum == null || maximum > thresholds.maximumAbsoluteErrorCents) {
      violations.add(
        'maximumAbsoluteErrorCents=$maximum > '
        '${thresholds.maximumAbsoluteErrorCents}',
      );
    }
    if (octaveErrorRate > thresholds.maximumOctaveErrorRate) {
      violations.add(
        'octaveErrorRate=$octaveErrorRate > '
        '${thresholds.maximumOctaveErrorRate}',
      );
    }
    return violations;
  }

  bool get passed => violations.isEmpty;

  Map<String, Object?> toJson() => {
    'windowSamples': windowSamples,
    'inputCount': inputCount,
    'estimateCount': estimateCount,
    'noEstimateCount': noEstimateCount,
    'medianAbsoluteErrorCents': medianAbsoluteErrorCents,
    'p95AbsoluteErrorCents': p95AbsoluteErrorCents,
    'maximumAbsoluteErrorCents': maximumAbsoluteErrorCents,
    'octaveErrorCount': octaveErrorCount,
    'octaveErrorRate': octaveErrorRate,
    'elapsedMilliseconds': elapsedMilliseconds,
    'passed': passed,
    'violations': violations,
  };
}

SyntheticAccuracyResult runPureSineCorpus({
  required PitchDetector detector,
  required int windowSamples,
  SyntheticAccuracyThresholds thresholds = const SyntheticAccuracyThresholds(),
}) {
  const sampleRate = TunerDspConfig.sampleRateHz;
  const maximumCorpusFrequencyHz = 1318.51;
  const baseFrequencies = <double>[
    43.65,
    55,
    82.41,
    110,
    329.63,
    440,
    880,
    maximumCorpusFrequencyHz,
  ];
  const offsets = <double>[-49, -17, -3, 0, 3, 17, 49];
  final absoluteErrors = <double>[];
  var inputCount = 0;
  var noEstimateCount = 0;
  var octaveErrorCount = 0;
  final stopwatch = Stopwatch()..start();

  for (final baseFrequency in baseFrequencies) {
    for (final offset in offsets) {
      final frequency = baseFrequency * math.pow(2, offset / 1200);
      if (frequency < TunerDspConfig.minimumFrequencyHz ||
          frequency > maximumCorpusFrequencyHz) {
        continue;
      }
      inputCount++;
      final estimate = detector.detect(
        generateSine(
          frequencyHz: frequency,
          sampleRate: sampleRate,
          length: windowSamples,
        ),
        sampleRate: sampleRate,
      );
      if (estimate == null) {
        noEstimateCount++;
        continue;
      }
      final ratio = estimate.frequencyHz / frequency;
      if ((ratio >= 0.48 && ratio <= 0.52) || (ratio >= 1.9 && ratio <= 2.1)) {
        octaveErrorCount++;
      }
      absoluteErrors.add(estimate.centsFrom(frequency).abs());
    }
  }
  stopwatch.stop();
  absoluteErrors.sort();

  return SyntheticAccuracyResult(
    windowSamples: windowSamples,
    inputCount: inputCount,
    estimateCount: absoluteErrors.length,
    noEstimateCount: noEstimateCount,
    medianAbsoluteErrorCents: _percentileOrNull(absoluteErrors, 0.5),
    p95AbsoluteErrorCents: _percentileOrNull(absoluteErrors, 0.95),
    maximumAbsoluteErrorCents: absoluteErrors.isEmpty
        ? null
        : absoluteErrors.last,
    octaveErrorCount: octaveErrorCount,
    elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    thresholds: thresholds,
  );
}

Float64List generateSine({
  required double frequencyHz,
  required double sampleRate,
  required int length,
}) {
  const phaseOffset = 0.37;
  return Float64List.fromList(
    List<double>.generate(
      length,
      (index) => math.sin(
        2 * math.pi * frequencyHz * index / sampleRate + phaseOffset,
      ),
    ),
  );
}

double? _percentileOrNull(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) {
    return null;
  }
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index];
}
