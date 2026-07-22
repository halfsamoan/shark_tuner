import 'dart:io';

import 'package:test/test.dart';

import '../tool/public_corpus_report.dart' as report;

void main() {
  test(
    'reports Bb3 raw 2f regression beside the corrected product path',
    () async {
      final manifest = _workspaceFile(
        'packages/tuner_dsp/test/fixtures/public/manifest.public.v1.json',
      );

      final document = await report.buildPublicCorpusReport(
        manifestFile: manifest,
      );
      final fixtures = (document['fixtures'] as List)
          .cast<Map<String, Object?>>();
      final bb3 = fixtures.singleWhere(
        (fixture) => fixture['id'] == 'user-s2-bb3-hard',
      );
      final raw = bb3['rawDetector']! as Map<String, Object?>;
      final product = bb3['productPipeline']! as Map<String, Object?>;
      final sanity = bb3['octaveSanity']! as Map<String, Object?>;
      final events = (sanity['events']! as List).cast<Map<String, Object?>>();

      expect(raw['octaveErrorCount'], 34);
      expect(product['octaveErrorCount'], 0);
      expect(sanity['rawHalfFrequencyCorrectionCount'], 0);
      expect(sanity['rawDoubleFrequencyCorrectionCount'], 34);
      expect(
        events,
        everyElement(
          allOf(
            containsPair('kind', 'rawDoubleFrequency'),
            containsPair('frequencyMultiplier', 0.5),
            containsPair('clarityGatePassed', true),
            predicate<Map<String, Object?>>(
              (event) => (event['windowStartMs']! as num) >= 600,
              'occurs inside the declared stable segment',
            ),
            predicate<Map<String, Object?>>(
              (event) => (event['clarity']! as num) >= 0.9,
              'passes the product clarity gate',
            ),
          ),
        ),
      );
    },
  );
}

File _workspaceFile(String relativePath) {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not find workspace file: $relativePath');
    }
    directory = parent;
  }
}
