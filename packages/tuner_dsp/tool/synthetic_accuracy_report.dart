import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  const sampleRate = TunerDspConfig.sampleRateHz;
  const detector = MpmDetector();
  const baseFrequencies = <double>[
    43.65,
    55,
    82.41,
    110,
    329.63,
    440,
    880,
    1318.51,
  ];
  const offsets = <double>[-49, -17, -3, 0, 3, 17, 49];
  final errors = <double>[];
  var noEstimateCount = 0;
  var octaveErrorCount = 0;
  final stopwatch = Stopwatch()..start();

  for (final baseFrequency in baseFrequencies) {
    for (final offset in offsets) {
      final frequency = baseFrequency * math.pow(2, offset / 1200);
      if (frequency < TunerDspConfig.minimumFrequencyHz ||
          frequency > 1318.51) {
        continue;
      }
      final samples = Float64List.fromList(
        List<double>.generate(
          TunerDspConfig.lowTuningWindowSize,
          (index) =>
              math.sin(2 * math.pi * frequency * index / sampleRate + 0.37),
        ),
      );
      final estimate = detector.detect(samples, sampleRate: sampleRate);
      if (estimate == null) {
        noEstimateCount++;
        continue;
      }
      final ratio = estimate.frequencyHz / frequency;
      if ((ratio >= 0.48 && ratio <= 0.52) || (ratio >= 1.9 && ratio <= 2.1)) {
        octaveErrorCount++;
      }
      errors.add(estimate.centsFrom(frequency).abs());
    }
  }
  stopwatch.stop();
  errors.sort();

  final report = <String, Object>{
    'gate': 'S1-pure-sine',
    'sampleRateHz': sampleRate,
    'windowSamples': TunerDspConfig.lowTuningWindowSize,
    'estimateCount': errors.length,
    'noEstimateCount': noEstimateCount,
    'medianAbsoluteErrorCents': _percentile(errors, 0.5),
    'p95AbsoluteErrorCents': _percentile(errors, 0.95),
    'maximumAbsoluteErrorCents': errors.last,
    'octaveErrorCount': octaveErrorCount,
    'elapsedMilliseconds': stopwatch.elapsedMilliseconds,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

double _percentile(List<double> sortedValues, double percentile) {
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index];
}
