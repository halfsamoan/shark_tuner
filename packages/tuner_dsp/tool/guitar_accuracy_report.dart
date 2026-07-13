import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tuner_dsp/tuner_dsp.dart';

import 'support/pcm16_wave.dart';

void main(List<String> arguments) {
  final requireCorpus = arguments.contains('--require-corpus');
  final manifestArgument = arguments
      .where((argument) => argument.startsWith('--manifest='))
      .firstOrNull;
  final manifestPath =
      manifestArgument?.substring('--manifest='.length) ??
      'test/fixtures/guitar/manifest.v1.json';
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('G1 manifest not found: ${manifestFile.absolute.path}');
    exitCode = 2;
    return;
  }
  final document = jsonDecode(manifestFile.readAsStringSync());
  if (document is! Map<String, dynamic> || document['schemaVersion'] != 1) {
    stderr.writeln('Unsupported G1 manifest schema.');
    exitCode = 2;
    return;
  }
  final fixtureDocuments = (document['fixtures'] as List)
      .cast<Map<String, dynamic>>();
  if (fixtureDocuments.isEmpty) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'gate': 'G1-recorded-guitar',
        'status': 'missing_corpus',
        'passed': null,
        'fixtureCount': 0,
        'next': 'Add WAV entries to test/fixtures/guitar/manifest.v1.json.',
      }),
    );
    if (requireCorpus) {
      exitCode = 2;
    }
    return;
  }

  const detector = MpmDetector();
  final results = <Map<String, Object?>>[];
  var totalEstimateCount = 0;
  var totalOctaveErrors = 0;
  var passed = true;
  for (final fixture in fixtureDocuments) {
    final result = _runFixture(
      detector: detector,
      manifestDirectory: manifestFile.absolute.parent,
      fixture: fixture,
      requiredSampleRateHz: document['requiredSampleRateHz'] as int,
    );
    results.add(result.json);
    totalEstimateCount += result.estimateCount;
    totalOctaveErrors += result.octaveErrorCount;
    passed = passed && result.passed;
  }
  final octaveErrorRate = totalEstimateCount == 0
      ? 0.0
      : totalOctaveErrors / totalEstimateCount;
  const maximumOctaveErrorRate = 0.005;
  if (octaveErrorRate >= maximumOctaveErrorRate) {
    passed = false;
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'gate': 'G1-recorded-guitar',
      'status': 'complete',
      'passed': passed,
      'fixtureCount': results.length,
      'overallEstimateCount': totalEstimateCount,
      'overallOctaveErrorCount': totalOctaveErrors,
      'overallOctaveErrorRate': octaveErrorRate,
      'maximumOctaveErrorRateExclusive': maximumOctaveErrorRate,
      'fixtures': results,
    }),
  );
  if (!passed) {
    exitCode = 1;
  }
}

_FixtureResult _runFixture({
  required PitchDetector detector,
  required Directory manifestDirectory,
  required Map<String, dynamic> fixture,
  required int requiredSampleRateHz,
}) {
  final id = fixture['id'] as String;
  final file = File.fromUri(
    manifestDirectory.uri.resolve(fixture['file'] as String),
  );
  final violations = <String>[];
  if (!file.existsSync()) {
    return _FixtureResult(
      estimateCount: 0,
      octaveErrorCount: 0,
      passed: false,
      json: {
        'id': id,
        'passed': false,
        'violations': ['missing WAV: ${file.path}'],
      },
    );
  }
  final wave = decodePcm16Wave(file.readAsBytesSync());
  if (wave.sampleRateHz != requiredSampleRateHz) {
    violations.add(
      'sampleRateHz=${wave.sampleRateHz} != $requiredSampleRateHz',
    );
  }
  final stableStart =
      ((fixture['stableStartMs'] as int) * wave.sampleRateHz / 1000).round();
  final stableEnd = ((fixture['stableEndMs'] as int) * wave.sampleRateHz / 1000)
      .round();
  final windowSamples = fixture['windowSamples'] as int;
  if (stableStart < 0 ||
      stableEnd > wave.monoSamples.length ||
      stableEnd - stableStart < windowSamples) {
    violations.add('stable segment is outside the WAV or shorter than window');
  }
  final referenceHz = (fixture['referenceFrequencyHz'] as num).toDouble();
  final errors = <double>[];
  var noEstimateCount = 0;
  var octaveErrorCount = 0;
  if (violations.where((item) => item.startsWith('stable segment')).isEmpty) {
    for (
      var offset = stableStart;
      offset + windowSamples <= stableEnd;
      offset += TunerDspConfig.hopSize
    ) {
      final estimate = detector.detect(
        Float64List.sublistView(
          wave.monoSamples,
          offset,
          offset + windowSamples,
        ),
        sampleRate: wave.sampleRateHz.toDouble(),
      );
      if (estimate == null) {
        noEstimateCount++;
        continue;
      }
      final ratio = estimate.frequencyHz / referenceHz;
      if ((ratio >= 0.48 && ratio <= 0.52) || (ratio >= 1.9 && ratio <= 2.1)) {
        octaveErrorCount++;
      }
      errors.add(estimate.centsFrom(referenceHz).abs());
    }
  }
  errors.sort();
  final median = _percentile(errors, 0.5);
  final p95 = _percentile(errors, 0.95);
  final isLow = fixture['group'] == 'low';
  final maximumMedian = isLow ? 2.0 : 1.0;
  const maximumP95 = 3.0;
  if (median == null || median > maximumMedian) {
    violations.add('medianAbsoluteErrorCents=$median > $maximumMedian');
  }
  if (p95 == null || p95 > maximumP95) {
    violations.add('p95AbsoluteErrorCents=$p95 > $maximumP95');
  }
  final attempted = errors.length + noEstimateCount;
  return _FixtureResult(
    estimateCount: errors.length,
    octaveErrorCount: octaveErrorCount,
    passed: violations.isEmpty,
    json: {
      'id': id,
      'file': fixture['file'],
      'group': fixture['group'],
      'stringLabel': fixture['stringLabel'],
      'pickStrength': fixture['pickStrength'],
      'stringAge': fixture['stringAge'],
      'pickup': fixture['pickup'],
      'capturePath': fixture['capturePath'],
      'referenceFrequencyHz': referenceHz,
      'referenceMethod': fixture['referenceMethod'],
      'sampleRateHz': wave.sampleRateHz,
      'windowSamples': windowSamples,
      'attemptedWindowCount': attempted,
      'estimateCount': errors.length,
      'noEstimateCount': noEstimateCount,
      'validEstimateRate': attempted == 0 ? 0 : errors.length / attempted,
      'medianAbsoluteErrorCents': median,
      'p95AbsoluteErrorCents': p95,
      'maximumAbsoluteErrorCents': errors.isEmpty ? null : errors.last,
      'octaveErrorCount': octaveErrorCount,
      'passed': violations.isEmpty,
      'violations': violations,
    },
  );
}

double? _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) {
    return null;
  }
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index];
}

final class _FixtureResult {
  const _FixtureResult({
    required this.estimateCount,
    required this.octaveErrorCount,
    required this.passed,
    required this.json,
  });

  final int estimateCount;
  final int octaveErrorCount;
  final bool passed;
  final Map<String, Object?> json;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
