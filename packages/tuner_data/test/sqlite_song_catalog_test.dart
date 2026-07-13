import 'dart:io';

import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  late String songsJson;
  late String tuningsJson;
  late SqliteSongCatalog catalog;

  setUpAll(() async {
    songsJson = await _workspaceFile(
      'data/songs/candidates.v1.json',
    ).readAsString();
    tuningsJson = await _workspaceFile(
      'data/songs/tunings.v1.json',
    ).readAsString();
  });

  setUp(() {
    catalog = SqliteSongCatalog.inMemory(
      songsDocumentJson: songsJson,
      tuningsDocumentJson: tuningsJson,
    );
  });

  tearDown(() async {
    await catalog.close();
  });

  test('FTS5 searches title and artist with prefixes while offline', () async {
    final metallica = await catalog.search('metal', includeUnverified: true);
    final mixedFields = await catalog.search(
      'foo ever',
      includeUnverified: true,
    );
    final punctuation = await catalog.search('AC/DC', includeUnverified: true);

    expect(metallica.map((match) => match.song.title).toSet(), {
      'Enter Sandman',
      'Master of Puppets',
    });
    expect(mixedFields.single.song.title, 'Everlong');
    expect(punctuation.map((match) => match.song.title).toSet(), {
      'Back in Black',
      'Highway to Hell',
    });
  });

  test('unverified candidates are hidden unless explicitly enabled', () async {
    expect(await catalog.search('Metallica'), isEmpty);
    expect(await catalog.getById('metallica-enter-sandman'), isNull);
    expect(
      await catalog.search('Metallica', includeUnverified: true),
      hasLength(2),
    );
  });

  test('a match owns the versioned tuning snapshot and capo fact', () async {
    final match = await catalog.getById(
      'the-beatles-here-comes-the-sun',
      includeUnverified: true,
    );

    expect(match, isNotNull);
    expect(match!.tuning.id, 'guitar-6-standard');
    expect(match.tuning.version, 1);
    expect(match.tuning.name, 'E Standard');
    expect(match.tuning.centsOffset, 0);
    expect(match.song.capoFret, 7);
    expect(
      match.tuning.strings.first.targetFrequencyHz(
        referenceA4Hz: match.tuning.referenceA4Hz,
        centsOffset: match.tuning.centsOffset,
      ),
      closeTo(82.41, 0.02),
    );
  });

  test(
    'compatible-song lookup respects tuning version and cents offset',
    () async {
      final everlong = await catalog.getById(
        'foo-fighters-everlong',
        includeUnverified: true,
      );
      final sweetChild = await catalog.getById(
        'guns-n-roses-sweet-child-o-mine',
        includeUnverified: true,
      );

      final dropDSongs = await catalog.findPlayableWith(
        everlong!.tuning,
        includeUnverified: true,
      );
      final eFlatSongs = await catalog.findPlayableWith(
        sweetChild!.tuning,
        includeUnverified: true,
      );

      expect(dropDSongs.map((match) => match.song.title).toSet(), {
        'Everlong',
        'Killing in the Name',
        'Schism',
      });
      expect(eFlatSongs.map((match) => match.song.title).toSet(), {
        "Sweet Child O' Mine",
      });
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
