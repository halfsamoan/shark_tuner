import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/import_song_backbone.dart' as importer;

void main() {
  test(
    'offline importer preserves quoted CSV and emits no shipping data',
    () async {
      final packageRoot = _packageRoot();
      final outputDirectory = await Directory.systemTemp.createTemp(
        'toauner-backbone-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));
      final fixtures = '${packageRoot.path}/test/fixtures/song_backbone';
      final output = '${outputDirectory.path}/backbone.json';

      await importer.main([
        '--canonical-csv',
        '$fixtures/canonical.csv',
        '--targets-json',
        '$fixtures/targets.json',
        '--popularity-json',
        '$fixtures/popularity.json',
        '--captured-at',
        '2026-07-14T00:00:00Z',
        '--output',
        output,
      ]);

      expect(await File(output).exists(), isTrue);
      final document = jsonDecode(await File(output).readAsString()) as Map;
      final song = (document['songs'] as List).single as Map;
      expect(document['shippingEligible'], isFalse);
      expect(song['artist'], 'Example, Artist');
      expect(song['title'], 'Example, Song');
      expect((song['priority'] as Map)['totalUserCount'], 321);
    },
  );
}

Directory _packageRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File(
      '${directory.path}/pubspec.yaml',
    ).readAsStringSync().contains('name: tuner_data')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not find tuner_data package root.');
    }
    directory = parent;
  }
}
