import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  late String songsJson;
  late String candidateSongsJson;
  late String tuningsJson;
  late SqliteSongCatalog catalog;

  setUpAll(() async {
    candidateSongsJson = await _workspaceFile(
      'data/songs/candidates.v1.json',
    ).readAsString();
    songsJson = await _workspaceFile(
      'data/songs/catalog.v1.json',
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
    final metallica = await catalog.search('metal');
    final mixedFields = await catalog.search('foo ever');
    final punctuation = await catalog.search('AC/DC');

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

  test('FTS5 searches curated Korean artist aliases offline', () async {
    final metallica = await catalog.search('메탈리카');
    final nirvana = await catalog.search('너바나');
    final guns = await catalog.search('건즈 앤 로지스');

    expect(metallica.map((match) => match.song.title).toSet(), {
      'Enter Sandman',
      'Master of Puppets',
    });
    expect(nirvana.map((match) => match.song.title).toSet(), {
      'Come as You Are',
      'Smells Like Teen Spirit',
    });
    expect(guns.single.song.title, "Sweet Child O' Mine");
    expect(guns.single.song.searchAliases, contains('건즈 앤 로지스'));
  });

  test('migrates an installed catalog created before alias search', () async {
    final directory = await Directory.systemTemp.createTemp(
      'toauner-song-catalog-',
    );
    final path = '${directory.path}/songs.sqlite';
    final legacy = sqlite.sqlite3.open(path);
    legacy.execute('''
      CREATE TABLE song (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        tuning_id TEXT NOT NULL,
        tuning_version INTEGER NOT NULL,
        capo_fret INTEGER NOT NULL,
        cents_offset REAL NOT NULL,
        verification_status TEXT NOT NULL,
        research_confidence TEXT NOT NULL,
        sources_json TEXT NOT NULL,
        notes TEXT NOT NULL
      )
    ''');
    legacy.execute('''
      CREATE VIRTUAL TABLE song_fts USING fts5(
        song_id UNINDEXED,
        title,
        artist,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    legacy.close();

    final migrated = SqliteSongCatalog.open(
      path: path,
      songsDocumentJson: songsJson,
      tuningsDocumentJson: tuningsJson,
    );
    try {
      final results = await migrated.search('메탈리카');
      expect(results, hasLength(2));
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });

  test('unverified candidates are hidden unless explicitly enabled', () async {
    final candidateCatalog = SqliteSongCatalog.inMemory(
      songsDocumentJson: candidateSongsJson,
      tuningsDocumentJson: tuningsJson,
    );
    try {
      expect(await candidateCatalog.search('Metallica'), isEmpty);
      expect(await candidateCatalog.getById('metallica-enter-sandman'), isNull);
      final researchMatches = await candidateCatalog.search(
        'Metallica',
        includeUnverified: true,
      );
      expect(researchMatches.map((match) => match.song.title).toSet(), {
        'Enter Sandman',
        'Master of Puppets',
        'Sad but True',
      });
    } finally {
      await candidateCatalog.close();
    }
  });

  test('a match owns the versioned tuning snapshot and capo fact', () async {
    final match = await catalog.getById('the-beatles-here-comes-the-sun');

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
      final everlong = await catalog.getById('foo-fighters-everlong');
      final sweetChild = await catalog.getById(
        'guns-n-roses-sweet-child-o-mine',
      );

      final dropDSongs = await catalog.findPlayableWith(everlong!.tuning);
      final eFlatSongs = await catalog.findPlayableWith(sweetChild!.tuning);

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
