import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tuner_dsp/tuner_dsp.dart';

import 'support/corpus_preparation.dart';
import 'support/pcm16_wave.dart';

Future<void> main(List<String> arguments) async {
  final manifestArgument = arguments
      .where((argument) => argument.startsWith('--manifest='))
      .firstOrNull;
  final outputArgument = arguments
      .where((argument) => argument.startsWith('--output='))
      .firstOrNull;
  final manifestPath =
      manifestArgument?.substring('--manifest='.length) ??
      'test/fixtures/public/manifest.public.v1.json';
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln(
      'Public corpus manifest not found: ${manifestFile.absolute.path}',
    );
    exitCode = 2;
    return;
  }
  try {
    final manifest = jsonDecode(manifestFile.readAsStringSync());
    if (manifest is! Map<String, dynamic> || manifest['schemaVersion'] != 1) {
      throw const FormatException('Unsupported public corpus manifest schema.');
    }
    final fixtures = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>();
    final detector = MpmDetector();
    final classAccumulators = <String, _MetricAccumulator>{};
    final fixtureResults = <Map<String, Object?>>[];
    for (final fixture in fixtures) {
      final result = await _analyzeFixture(
        detector: detector,
        fixture: fixture,
        manifestDirectory: manifestFile.absolute.parent,
      );
      fixtureResults.add(result.json);
      classAccumulators
          .putIfAbsent(result.corpusClass, _MetricAccumulator.new)
          .add(result);
    }
    final classes = <String, Object?>{
      for (final entry
          in classAccumulators.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key)))
        entry.key: entry.value.toJson(),
    };
    final report = const JsonEncoder.withIndent('  ').convert({
      'report': 'public-recorded-guitar-baseline',
      'status': 'informational',
      'passed': null,
      'isRegressionGate': false,
      'groundTruth': 'nominal MIDI note; not a sub-cent reference',
      'fixtureCount': fixtures.length,
      'classes': classes,
      'fixtures': fixtureResults,
    });
    final outputPath = outputArgument?.substring('--output='.length);
    if (outputPath == null) {
      stdout.writeln(report);
    } else {
      final outputFile = File(outputPath).absolute;
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync('$report\n');
      stdout.writeln(
        jsonEncode({
          'status': 'complete',
          'fixtureCount': fixtures.length,
          'output': outputFile.path,
        }),
      );
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Public corpus report failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 2;
  }
}

Future<_FixtureMetrics> _analyzeFixture({
  required PitchDetector detector,
  required Map<String, dynamic> fixture,
  required Directory manifestDirectory,
}) async {
  final id = fixture['id'] as String;
  final corpusClass = fixture['corpusClass'] as String;
  final file = File.fromUri(
    manifestDirectory.uri.resolve(fixture['file'] as String),
  );
  if (!file.existsSync()) {
    throw StateError('Missing public corpus fixture: ${file.path}');
  }
  final expectedHash = fixture['outputSha256'] as String;
  final actualHash = await sha256File(file);
  if (actualHash != expectedHash) {
    throw StateError('Fixture hash mismatch for $id.');
  }
  final wave = decodePcm16Wave(file.readAsBytesSync());
  final expectedSampleRate = fixture['outputSampleRateHz'] as int;
  if (wave.sampleRateHz != expectedSampleRate) {
    throw StateError(
      '$id sample rate is ${wave.sampleRateHz}, expected $expectedSampleRate.',
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
    throw StateError('$id has an invalid stable analysis segment.');
  }
  final nominalHz = (fixture['nominalFrequencyHz'] as num).toDouble();
  final frequencies = <double>[];
  final nominalAbsoluteErrors = <double>[];
  var grossNoteErrorCount = 0;
  var noEstimateCount = 0;
  var octaveErrorCount = 0;
  final hopSamples = windowSamples == TunerDspConfig.lowTuningWindowSize
      ? TunerDspConfig.lowTuningHopSize
      : TunerDspConfig.hopSize;
  for (
    var offset = stableStart;
    offset + windowSamples <= stableEnd;
    offset += hopSamples
  ) {
    final estimate = detector.detect(
      Float64List.sublistView(wave.monoSamples, offset, offset + windowSamples),
      sampleRate: wave.sampleRateHz.toDouble(),
    );
    if (estimate == null) {
      noEstimateCount++;
      continue;
    }
    frequencies.add(estimate.frequencyHz);
    final ratio = estimate.frequencyHz / nominalHz;
    if ((ratio >= 0.48 && ratio <= 0.52) || (ratio >= 1.9 && ratio <= 2.1)) {
      octaveErrorCount++;
    }
    final nominalAbsoluteError = _cents(estimate.frequencyHz, nominalHz).abs();
    nominalAbsoluteErrors.add(nominalAbsoluteError);
    if (nominalAbsoluteError > 50) {
      grossNoteErrorCount++;
    }
  }
  final sortedFrequencies = frequencies.toList()..sort();
  final medianFrequency = _percentile(sortedFrequencies, 0.5);
  final selfConsistencyErrors = medianFrequency == null
      ? <double>[]
      : [
          for (final frequency in frequencies)
            _cents(frequency, medianFrequency).abs(),
        ];
  nominalAbsoluteErrors.sort();
  selfConsistencyErrors.sort();
  return _FixtureMetrics(
    attemptedWindowCount: frequencies.length + noEstimateCount,
    corpusClass: corpusClass,
    grossNoteErrorCount: grossNoteErrorCount,
    id: id,
    noEstimateCount: noEstimateCount,
    nominalAbsoluteErrors: nominalAbsoluteErrors,
    octaveErrorCount: octaveErrorCount,
    selfConsistencyErrors: selfConsistencyErrors,
  );
}

double _cents(double frequencyHz, double referenceHz) =>
    1200 * math.log(frequencyHz / referenceHz) / math.ln2;

double? _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) {
    return null;
  }
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index];
}

final class _FixtureMetrics {
  const _FixtureMetrics({
    required this.attemptedWindowCount,
    required this.corpusClass,
    required this.grossNoteErrorCount,
    required this.id,
    required this.noEstimateCount,
    required this.nominalAbsoluteErrors,
    required this.octaveErrorCount,
    required this.selfConsistencyErrors,
  });

  final int attemptedWindowCount;
  final String corpusClass;
  final int grossNoteErrorCount;
  final String id;
  final int noEstimateCount;
  final List<double> nominalAbsoluteErrors;
  final int octaveErrorCount;
  final List<double> selfConsistencyErrors;

  int get estimateCount => nominalAbsoluteErrors.length;

  Map<String, Object?> get json => {
    'id': id,
    'corpusClass': corpusClass,
    'attemptedWindowCount': attemptedWindowCount,
    'estimateCount': estimateCount,
    'noEstimateCount': noEstimateCount,
    'validEstimateRate': attemptedWindowCount == 0
        ? 0.0
        : estimateCount / attemptedWindowCount,
    'octaveErrorCount': octaveErrorCount,
    'octaveErrorRate': estimateCount == 0
        ? 0.0
        : octaveErrorCount / estimateCount,
    'grossNoteErrorCount': grossNoteErrorCount,
    'grossNoteErrorRate': estimateCount == 0
        ? 0.0
        : grossNoteErrorCount / estimateCount,
    'medianAbsoluteNominalDeviationCents': _percentile(
      nominalAbsoluteErrors,
      0.5,
    ),
    'p95AbsoluteNominalDeviationCents': _percentile(
      nominalAbsoluteErrors,
      0.95,
    ),
    'medianSelfConsistencyCents': _percentile(selfConsistencyErrors, 0.5),
    'p95SelfConsistencyCents': _percentile(selfConsistencyErrors, 0.95),
  };
}

final class _MetricAccumulator {
  int attemptedWindowCount = 0;
  int noEstimateCount = 0;
  int octaveErrorCount = 0;
  int grossNoteErrorCount = 0;
  final List<double> nominalAbsoluteErrors = [];
  final List<double> selfConsistencyErrors = [];

  void add(_FixtureMetrics metrics) {
    attemptedWindowCount += metrics.attemptedWindowCount;
    noEstimateCount += metrics.noEstimateCount;
    octaveErrorCount += metrics.octaveErrorCount;
    grossNoteErrorCount += metrics.grossNoteErrorCount;
    nominalAbsoluteErrors.addAll(metrics.nominalAbsoluteErrors);
    selfConsistencyErrors.addAll(metrics.selfConsistencyErrors);
  }

  Map<String, Object?> toJson() {
    nominalAbsoluteErrors.sort();
    selfConsistencyErrors.sort();
    final estimateCount = nominalAbsoluteErrors.length;
    return {
      'attemptedWindowCount': attemptedWindowCount,
      'estimateCount': estimateCount,
      'noEstimateCount': noEstimateCount,
      'validEstimateRate': attemptedWindowCount == 0
          ? 0.0
          : estimateCount / attemptedWindowCount,
      'octaveErrorCount': octaveErrorCount,
      'octaveErrorRate': estimateCount == 0
          ? 0.0
          : octaveErrorCount / estimateCount,
      'grossNoteErrorCount': grossNoteErrorCount,
      'grossNoteErrorRate': estimateCount == 0
          ? 0.0
          : grossNoteErrorCount / estimateCount,
      'medianAbsoluteNominalDeviationCents': _percentile(
        nominalAbsoluteErrors,
        0.5,
      ),
      'p95AbsoluteNominalDeviationCents': _percentile(
        nominalAbsoluteErrors,
        0.95,
      ),
      'maximumAbsoluteNominalDeviationCents': nominalAbsoluteErrors.isEmpty
          ? null
          : nominalAbsoluteErrors.last,
      'medianSelfConsistencyCents': _percentile(selfConsistencyErrors, 0.5),
      'p95SelfConsistencyCents': _percentile(selfConsistencyErrors, 0.95),
      'maximumSelfConsistencyCents': selfConsistencyErrors.isEmpty
          ? null
          : selfConsistencyErrors.last,
    };
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
