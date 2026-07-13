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
    final document = await buildPublicCorpusReport(manifestFile: manifestFile);
    final report = const JsonEncoder.withIndent('  ').convert(document);
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
          'fixtureCount': document['fixtureCount'],
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

Future<Map<String, Object?>> buildPublicCorpusReport({
  required File manifestFile,
}) async {
  final manifest = jsonDecode(manifestFile.readAsStringSync());
  if (manifest is! Map<String, dynamic> || manifest['schemaVersion'] != 1) {
    throw const FormatException('Unsupported public corpus manifest schema.');
  }
  final fixtures = (manifest['fixtures'] as List).cast<Map<String, dynamic>>();
  final detector = MpmDetector();
  final classAccumulators = <String, _DualMetricAccumulator>{};
  final segmentAccumulators = <String, Map<String, _DualMetricAccumulator>>{};
  final fixtureResults = <Map<String, Object?>>[];
  for (final fixture in fixtures) {
    final result = await _analyzeFixture(
      detector: detector,
      fixture: fixture,
      manifestDirectory: manifestFile.absolute.parent,
    );
    fixtureResults.add(result.json);
    classAccumulators
        .putIfAbsent(result.corpusClass, _DualMetricAccumulator.new)
        .add(result);
    for (final segment in result.segments.entries) {
      segmentAccumulators
          .putIfAbsent(result.corpusClass, () => {})
          .putIfAbsent(
            '${segment.key}:${segment.value}',
            _DualMetricAccumulator.new,
          )
          .add(result);
    }
  }
  final classes = <String, Object?>{
    for (final entry
        in classAccumulators.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)))
      entry.key: entry.value.toJson(),
  };
  final segments = <String, Object?>{
    for (final classEntry
        in segmentAccumulators.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)))
      classEntry.key: <String, Object?>{
        for (final segmentEntry
            in classEntry.value.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key)))
          segmentEntry.key: segmentEntry.value.toJson(),
      },
  };
  return {
    'report': 'public-recorded-guitar-baseline',
    'status': 'informational',
    'passed': null,
    'isRegressionGate': false,
    'groundTruth': 'nominal MIDI note; not a sub-cent reference',
    'pipelineOrder': [
      'detector',
      'clarity_gate',
      'target_or_previous_stable_octave_sanity',
      'median_of_5',
      'log_frequency_ema',
    ],
    'fixtureCount': fixtures.length,
    'classes': classes,
    'segments': segments,
    'fixtures': fixtureResults,
  };
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
  final pipeline = PitchTrackingPipeline(
    targetFrequenciesHz: _targetFrequencies(fixture),
  );
  final segments = <String, String>{};
  if (corpusClass == 'user-guitar') {
    segments.addAll({
      'tuning': fixture['offTuning'] == true ? 'semitone-down' : 'standard',
      'string': 's${fixture['stringNumber']}',
      'pickStrength': fixture['pickStrength'] as String,
      'clipping': fixture['clippingDetected'] == true ? 'detected' : 'clear',
    });
  }
  final rawFrequencies = <double>[];
  final productFrequencies = <double>[];
  final correctionEvents = <Map<String, Object?>>[];
  var attemptedWindowCount = 0;
  var clarityRejectedRawEstimateCount = 0;
  var rawHalfFrequencyCorrectionCount = 0;
  var rawDoubleFrequencyCorrectionCount = 0;
  final hopSamples = windowSamples == TunerDspConfig.lowTuningWindowSize
      ? TunerDspConfig.lowTuningHopSize
      : TunerDspConfig.hopSize;
  for (
    var offset = stableStart;
    offset + windowSamples <= stableEnd;
    offset += hopSamples
  ) {
    attemptedWindowCount++;
    final raw = detector.detect(
      Float64List.sublistView(wave.monoSamples, offset, offset + windowSamples),
      sampleRate: wave.sampleRateHz.toDouble(),
    );
    if (raw != null) {
      rawFrequencies.add(raw.frequencyHz);
    }
    final tracked = pipeline.process(raw);
    if (raw != null && !tracked.confidenceAccepted) {
      clarityRejectedRawEstimateCount++;
    }
    final octave = tracked.octaveSanity;
    if (octave?.corrected ?? false) {
      switch (octave!.kind) {
        case OctaveCorrectionKind.rawHalfFrequency:
          rawHalfFrequencyCorrectionCount++;
        case OctaveCorrectionKind.rawDoubleFrequency:
          rawDoubleFrequencyCorrectionCount++;
        case OctaveCorrectionKind.none:
          break;
      }
      correctionEvents.add({
        'windowStartMs': offset * 1000 / wave.sampleRateHz,
        'rawFrequencyHz': raw!.frequencyHz,
        'correctedFrequencyHz': octave.estimate.frequencyHz,
        'frequencyMultiplier': octave.frequencyMultiplier,
        'kind': octave.kind.name,
        'anchor': octave.anchor.name,
        'clarity': raw.clarity,
        'clarityGatePassed': tracked.confidenceAccepted,
      });
    }
    final product = tracked.stabilized;
    if (product != null) {
      productFrequencies.add(product.frequencyHz);
    }
  }
  return _FixtureMetrics(
    clarityRejectedRawEstimateCount: clarityRejectedRawEstimateCount,
    corpusClass: corpusClass,
    correctionEvents: correctionEvents,
    id: id,
    productPipeline: _buildSeries(
      attemptedWindowCount: attemptedWindowCount,
      frequencies: productFrequencies,
      nominalHz: nominalHz,
    ),
    rawDetector: _buildSeries(
      attemptedWindowCount: attemptedWindowCount,
      frequencies: rawFrequencies,
      nominalHz: nominalHz,
    ),
    rawDoubleFrequencyCorrectionCount: rawDoubleFrequencyCorrectionCount,
    rawHalfFrequencyCorrectionCount: rawHalfFrequencyCorrectionCount,
    segments: segments,
  );
}

List<double> _targetFrequencies(Map<String, dynamic> fixture) {
  if (fixture['corpusClass'] != 'user-guitar') {
    return [(fixture['nominalFrequencyHz'] as num).toDouble()];
  }
  final midiNotes = fixture['offTuning'] == true
      ? const [39, 44, 49, 54, 58, 63]
      : const [40, 45, 50, 55, 59, 64];
  return [for (final note in midiNotes) _midiFrequency(note)];
}

double _midiFrequency(int midiNote) =>
    440 * math.pow(2, (midiNote - 69) / 12).toDouble();

_MetricSeries _buildSeries({
  required int attemptedWindowCount,
  required List<double> frequencies,
  required double nominalHz,
}) {
  final nominalAbsoluteErrors = <double>[];
  var grossNoteErrorCount = 0;
  var octaveErrorCount = 0;
  for (final frequency in frequencies) {
    final ratio = frequency / nominalHz;
    if ((ratio >= 0.48 && ratio <= 0.52) || (ratio >= 1.9 && ratio <= 2.1)) {
      octaveErrorCount++;
    }
    final nominalAbsoluteError = _cents(frequency, nominalHz).abs();
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
  return _MetricSeries(
    attemptedWindowCount: attemptedWindowCount,
    grossNoteErrorCount: grossNoteErrorCount,
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

final class _MetricSeries {
  const _MetricSeries({
    required this.attemptedWindowCount,
    required this.grossNoteErrorCount,
    required this.nominalAbsoluteErrors,
    required this.octaveErrorCount,
    required this.selfConsistencyErrors,
  });

  final int attemptedWindowCount;
  final int grossNoteErrorCount;
  final List<double> nominalAbsoluteErrors;
  final int octaveErrorCount;
  final List<double> selfConsistencyErrors;

  int get estimateCount => nominalAbsoluteErrors.length;
  int get noEstimateCount => attemptedWindowCount - estimateCount;

  Map<String, Object?> toJson({bool includeMaximum = false}) => {
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
    'errorOver50CentsCount': grossNoteErrorCount,
    'errorOver50CentsRate': estimateCount == 0
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
    if (includeMaximum)
      'maximumAbsoluteNominalDeviationCents': nominalAbsoluteErrors.isEmpty
          ? null
          : nominalAbsoluteErrors.last,
    'medianSelfConsistencyCents': _percentile(selfConsistencyErrors, 0.5),
    'p95SelfConsistencyCents': _percentile(selfConsistencyErrors, 0.95),
    if (includeMaximum)
      'maximumSelfConsistencyCents': selfConsistencyErrors.isEmpty
          ? null
          : selfConsistencyErrors.last,
  };
}

final class _FixtureMetrics {
  const _FixtureMetrics({
    required this.clarityRejectedRawEstimateCount,
    required this.corpusClass,
    required this.correctionEvents,
    required this.id,
    required this.productPipeline,
    required this.rawDetector,
    required this.rawDoubleFrequencyCorrectionCount,
    required this.rawHalfFrequencyCorrectionCount,
    required this.segments,
  });

  final int clarityRejectedRawEstimateCount;
  final String corpusClass;
  final List<Map<String, Object?>> correctionEvents;
  final String id;
  final _MetricSeries productPipeline;
  final _MetricSeries rawDetector;
  final int rawDoubleFrequencyCorrectionCount;
  final int rawHalfFrequencyCorrectionCount;
  final Map<String, String> segments;

  Map<String, Object?> get json => {
    'id': id,
    'corpusClass': corpusClass,
    if (segments.isNotEmpty) 'segments': segments,
    ...rawDetector.toJson(),
    'rawDetector': rawDetector.toJson(),
    'productPipeline': productPipeline.toJson(),
    'octaveSanity': {
      'rawHalfFrequencyCorrectionCount': rawHalfFrequencyCorrectionCount,
      'rawDoubleFrequencyCorrectionCount': rawDoubleFrequencyCorrectionCount,
      'clarityRejectedRawEstimateCount': clarityRejectedRawEstimateCount,
      'events': correctionEvents,
    },
  };
}

final class _MetricAccumulator {
  int attemptedWindowCount = 0;
  int grossNoteErrorCount = 0;
  int octaveErrorCount = 0;
  final List<double> nominalAbsoluteErrors = [];
  final List<double> selfConsistencyErrors = [];

  void add(_MetricSeries series) {
    attemptedWindowCount += series.attemptedWindowCount;
    grossNoteErrorCount += series.grossNoteErrorCount;
    octaveErrorCount += series.octaveErrorCount;
    nominalAbsoluteErrors.addAll(series.nominalAbsoluteErrors);
    selfConsistencyErrors.addAll(series.selfConsistencyErrors);
  }

  Map<String, Object?> toJson() {
    nominalAbsoluteErrors.sort();
    selfConsistencyErrors.sort();
    return _MetricSeries(
      attemptedWindowCount: attemptedWindowCount,
      grossNoteErrorCount: grossNoteErrorCount,
      nominalAbsoluteErrors: nominalAbsoluteErrors,
      octaveErrorCount: octaveErrorCount,
      selfConsistencyErrors: selfConsistencyErrors,
    ).toJson(includeMaximum: true);
  }
}

final class _DualMetricAccumulator {
  int fixtureCount = 0;
  int clarityRejectedRawEstimateCount = 0;
  int rawHalfFrequencyCorrectionCount = 0;
  int rawDoubleFrequencyCorrectionCount = 0;
  final _MetricAccumulator rawDetector = _MetricAccumulator();
  final _MetricAccumulator productPipeline = _MetricAccumulator();

  void add(_FixtureMetrics metrics) {
    fixtureCount++;
    rawDetector.add(metrics.rawDetector);
    productPipeline.add(metrics.productPipeline);
    clarityRejectedRawEstimateCount += metrics.clarityRejectedRawEstimateCount;
    rawHalfFrequencyCorrectionCount += metrics.rawHalfFrequencyCorrectionCount;
    rawDoubleFrequencyCorrectionCount +=
        metrics.rawDoubleFrequencyCorrectionCount;
  }

  Map<String, Object?> toJson() {
    final raw = rawDetector.toJson();
    return {
      'fixtureCount': fixtureCount,
      ...raw,
      'rawDetector': raw,
      'productPipeline': productPipeline.toJson(),
      'octaveSanity': {
        'rawHalfFrequencyCorrectionCount': rawHalfFrequencyCorrectionCount,
        'rawDoubleFrequencyCorrectionCount': rawDoubleFrequencyCorrectionCount,
        'clarityRejectedRawEstimateCount': clarityRejectedRawEstimateCount,
      },
    };
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
