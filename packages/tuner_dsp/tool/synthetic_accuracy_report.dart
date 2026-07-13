import 'dart:convert';
import 'dart:io';

import 'package:tuner_dsp/tuner_dsp.dart';

import '../test/support/synthetic_pitch_corpus.dart';

void main() {
  final detector = MpmDetector();
  const thresholds = SyntheticAccuracyThresholds();
  final results = [
    for (final windowSamples in [
      TunerDspConfig.standardWindowSize,
      TunerDspConfig.lowTuningWindowSize,
    ])
      runPureSineCorpus(
        detector: detector,
        windowSamples: windowSamples,
        thresholds: thresholds,
      ),
  ];
  final passed = results.every((result) => result.passed);
  final report = <String, Object>{
    'gate': 'S1-pure-sine',
    'passed': passed,
    'sampleRateHz': TunerDspConfig.sampleRateHz,
    'thresholds': thresholds.toJson(),
    'windows': results.map((result) => result.toJson()).toList(),
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));

  if (!passed) {
    for (final result in results.where((result) => !result.passed)) {
      stderr.writeln(
        'S1 failed for ${result.windowSamples} samples: '
        '${result.violations.join('; ')}',
      );
    }
    exitCode = 1;
  }
}
