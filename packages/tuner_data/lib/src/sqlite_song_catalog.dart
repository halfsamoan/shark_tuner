import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tuner_domain/tuner_domain.dart';

import 'song_catalog.dart';
import 'song_tuning_match.dart';
import 'song_tuning_record.dart';

final class SqliteSongCatalog implements SongCatalog {
  SqliteSongCatalog._(
    this._database, {
    required String songsDocumentJson,
    required String tuningsDocumentJson,
    // (Claude) optional unverified-candidate document merged in alongside the
    // verified release catalog. Candidate rows keep their draft status, so the
    // existing verification query filter hides them from release builds and
    // only surfaces them when includeUnverified is true (debug/dev).
    String? candidateSongsDocumentJson,
  }) {
    _createSchema();
    _replaceSeedData(
      songsDocumentJson: songsDocumentJson,
      tuningsDocumentJson: tuningsDocumentJson,
      candidateSongsDocumentJson: candidateSongsDocumentJson,
    );
  }

  factory SqliteSongCatalog.inMemory({
    required String songsDocumentJson,
    required String tuningsDocumentJson,
    String? candidateSongsDocumentJson, // (Claude)
  }) {
    return SqliteSongCatalog._(
      sqlite.sqlite3.openInMemory(),
      songsDocumentJson: songsDocumentJson,
      tuningsDocumentJson: tuningsDocumentJson,
      candidateSongsDocumentJson: candidateSongsDocumentJson,
    );
  }

  factory SqliteSongCatalog.open({
    required String path,
    required String songsDocumentJson,
    required String tuningsDocumentJson,
    String? candidateSongsDocumentJson, // (Claude)
  }) {
    return SqliteSongCatalog._(
      sqlite.sqlite3.open(path),
      songsDocumentJson: songsDocumentJson,
      tuningsDocumentJson: tuningsDocumentJson,
      candidateSongsDocumentJson: candidateSongsDocumentJson,
    );
  }

  final sqlite.Database _database;
  bool _closed = false;

  @override
  Future<List<SongTuningMatch>> search(
    String query, {
    bool includeUnverified = false,
  }) async {
    _ensureOpen();
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return _selectMatches(
        '''
        $_joinedSelect
        WHERE (? = 1 OR s.verification_status = 'verified')
        ORDER BY s.artist COLLATE NOCASE, s.title COLLATE NOCASE
        ''',
        [includeUnverified ? 1 : 0],
      );
    }

    return _selectMatches(
      '''
      $_joinedSelect
      JOIN song_fts f ON f.song_id = s.id
      WHERE song_fts MATCH ?
        AND (? = 1 OR s.verification_status = 'verified')
      ORDER BY bm25(song_fts), s.artist COLLATE NOCASE, s.title COLLATE NOCASE
      ''',
      [_ftsQuery(normalized), includeUnverified ? 1 : 0],
    );
  }

  @override
  Future<SongTuningMatch?> getById(
    String id, {
    bool includeUnverified = false,
  }) async {
    _ensureOpen();
    final matches = _selectMatches(
      '''
      $_joinedSelect
      WHERE s.id = ?
        AND (? = 1 OR s.verification_status = 'verified')
      LIMIT 1
      ''',
      [id, includeUnverified ? 1 : 0],
    );
    return matches.firstOrNull;
  }

  @override
  Future<List<SongTuningMatch>> findPlayableWith(
    TuningDefinition tuning, {
    bool includeUnverified = false,
  }) async {
    _ensureOpen();
    return _selectMatches(
      '''
      $_joinedSelect
      WHERE t.id = ?
        AND t.version = ?
        AND ABS(t.cents_offset + s.cents_offset - ?) < 0.000001
        AND (? = 1 OR s.verification_status = 'verified')
      ORDER BY s.artist COLLATE NOCASE, s.title COLLATE NOCASE
      ''',
      [
        tuning.id,
        tuning.version,
        tuning.centsOffset,
        includeUnverified ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _database.close();
    _closed = true;
  }

  void _createSchema() {
    _database.execute('PRAGMA foreign_keys = ON');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS tuning (
        id TEXT NOT NULL,
        version INTEGER NOT NULL,
        name TEXT NOT NULL,
        family TEXT NOT NULL,
        reference_a4_hz REAL NOT NULL,
        cents_offset REAL NOT NULL,
        accidental_style TEXT NOT NULL,
        midi_notes_json TEXT NOT NULL,
        PRIMARY KEY (id, version)
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS song (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        tuning_id TEXT NOT NULL,
        tuning_version INTEGER NOT NULL,
        capo_fret INTEGER NOT NULL,
        cents_offset REAL NOT NULL,
        verification_status TEXT NOT NULL,
        research_confidence TEXT NOT NULL,
        search_aliases_json TEXT NOT NULL DEFAULT '[]',
        sources_json TEXT NOT NULL,
        musicbrainz_recording_mbid TEXT,
        notes TEXT NOT NULL,
        FOREIGN KEY (tuning_id, tuning_version)
          REFERENCES tuning (id, version)
      )
    ''');
    final songColumns = _database
        .select('PRAGMA table_info(song)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!songColumns.contains('search_aliases_json')) {
      _database.execute(
        "ALTER TABLE song ADD COLUMN search_aliases_json TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (!songColumns.contains('musicbrainz_recording_mbid')) {
      _database.execute(
        'ALTER TABLE song ADD COLUMN musicbrainz_recording_mbid TEXT',
      );
    }
    final searchColumns = _database
        .select('PRAGMA table_info(song_fts)')
        .map((row) => row['name'] as String)
        .toSet();
    if (searchColumns.isNotEmpty && !searchColumns.contains('aliases')) {
      _database.execute('DROP TABLE song_fts');
    }
    _database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS song_fts USING fts5(
        song_id UNINDEXED,
        title,
        artist,
        aliases,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  void _replaceSeedData({
    required String songsDocumentJson,
    required String tuningsDocumentJson,
    String? candidateSongsDocumentJson, // (Claude)
  }) {
    final tunings = _parseTunings(tuningsDocumentJson);
    // (Claude) Merge verified release songs with optional draft candidates,
    // skipping any candidate that duplicates a verified song by id or by
    // normalized artist+title so debug search never shows the same song twice.
    final songs = _parseSongs(songsDocumentJson);
    if (candidateSongsDocumentJson != null) {
      String key(SongTuningRecord s) => '${s.artist}|${s.title}'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9|]'), '');
      final seenIds = {for (final s in songs) s.id};
      final seenKeys = {for (final s in songs) key(s)};
      for (final candidate in _parseSongs(candidateSongsDocumentJson)) {
        if (seenIds.contains(candidate.id) ||
            seenKeys.contains(key(candidate))) {
          continue;
        }
        seenIds.add(candidate.id);
        seenKeys.add(key(candidate));
        songs.add(candidate);
      }
    }
    final tuningKeys = {
      for (final tuning in tunings) '${tuning.id}@${tuning.version}',
    };
    for (final song in songs) {
      final tuningKey = '${song.tuningId}@${song.tuningVersion}';
      if (!tuningKeys.contains(tuningKey)) {
        throw FormatException(
          'Song ${song.id} references missing tuning $tuningKey.',
        );
      }
    }

    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute('DELETE FROM song_fts');
      _database.execute('DELETE FROM song');
      _database.execute('DELETE FROM tuning');

      final insertTuning = _database.prepare('''
        INSERT INTO tuning (
          id, version, name, family, reference_a4_hz, cents_offset,
          accidental_style, midi_notes_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final tuning in tunings) {
          insertTuning.execute([
            tuning.id,
            tuning.version,
            tuning.name,
            tuning.family,
            tuning.referenceA4Hz,
            tuning.centsOffset,
            tuning.accidentalStyle,
            jsonEncode(tuning.midiNotes),
          ]);
        }
      } finally {
        insertTuning.close();
      }

      final insertSong = _database.prepare('''
        INSERT INTO song (
          id, title, artist, tuning_id, tuning_version, capo_fret,
          cents_offset, verification_status, research_confidence,
          search_aliases_json, sources_json, musicbrainz_recording_mbid, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      final insertSearch = _database.prepare(
        'INSERT INTO song_fts (song_id, title, artist, aliases) '
        'VALUES (?, ?, ?, ?)',
      );
      try {
        for (final song in songs) {
          insertSong.execute([
            song.id,
            song.title,
            song.artist,
            song.tuningId,
            song.tuningVersion,
            song.capoFret,
            song.centsOffset,
            _verificationStatusValue(song.verificationStatus),
            _researchConfidenceValue(song.researchConfidence),
            jsonEncode(song.searchAliases),
            jsonEncode(song.sources.map(_sourceToJson).toList()),
            song.musicBrainzRecordingMbid,
            song.notes,
          ]);
          insertSearch.execute([
            song.id,
            song.title,
            song.artist,
            song.searchAliases.join(' '),
          ]);
        }
      } finally {
        insertSong.close();
        insertSearch.close();
      }
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  List<SongTuningMatch> _selectMatches(String sql, List<Object?> parameters) {
    return [
      for (final row in _database.select(sql, parameters)) _rowToMatch(row),
    ];
  }

  SongTuningMatch _rowToMatch(sqlite.Row row) {
    final sources = (jsonDecode(row['sources_json'] as String) as List)
        .cast<Map<String, dynamic>>()
        .map(_sourceFromJson)
        .toList();
    final song = SongTuningRecord(
      id: row['song_id'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String,
      searchAliases: (jsonDecode(row['search_aliases_json'] as String) as List)
          .cast<String>(),
      tuningId: row['tuning_id'] as String,
      tuningVersion: row['tuning_version'] as int,
      capoFret: row['capo_fret'] as int,
      centsOffset: (row['song_cents_offset'] as num).toDouble(),
      verificationStatus: _parseVerificationStatus(
        row['verification_status'] as String,
      ),
      researchConfidence: _parseResearchConfidence(
        row['research_confidence'] as String,
      ),
      sources: sources,
      musicBrainzRecordingMbid: row['musicbrainz_recording_mbid'] as String?,
      notes: row['notes'] as String,
    );
    final midiNotes = (jsonDecode(row['midi_notes_json'] as String) as List)
        .cast<num>()
        .map((note) => note.toInt())
        .toList();
    final useFlats = row['accidental_style'] == 'flat';
    final tuning = TuningDefinition(
      id: row['tuning_id'] as String,
      version: row['tuning_version'] as int,
      name: row['tuning_name'] as String,
      strings: [
        for (var index = 0; index < midiNotes.length; index++)
          TuningString(
            stringNumber: midiNotes.length - index,
            midiNote: midiNotes[index],
            label: _midiLabel(midiNotes[index], useFlats: useFlats),
          ),
      ],
      referenceA4Hz: (row['reference_a4_hz'] as num).toDouble(),
      centsOffset:
          (row['tuning_cents_offset'] as num).toDouble() + song.centsOffset,
    );
    return SongTuningMatch(song: song, tuning: tuning);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('The song catalog is closed.');
    }
  }
}

const _joinedSelect = '''
  SELECT
    s.id AS song_id,
    s.title,
    s.artist,
    s.capo_fret,
    s.cents_offset AS song_cents_offset,
    s.verification_status,
    s.research_confidence,
    s.search_aliases_json,
    s.sources_json,
    s.musicbrainz_recording_mbid,
    s.notes,
    t.id AS tuning_id,
    t.version AS tuning_version,
    t.name AS tuning_name,
    t.reference_a4_hz,
    t.cents_offset AS tuning_cents_offset,
    t.accidental_style,
    t.midi_notes_json
  FROM song s
  JOIN tuning t
    ON t.id = s.tuning_id AND t.version = s.tuning_version
''';

final class _SeedTuning {
  const _SeedTuning({
    required this.id,
    required this.version,
    required this.name,
    required this.family,
    required this.referenceA4Hz,
    required this.centsOffset,
    required this.accidentalStyle,
    required this.midiNotes,
  });

  final String id;
  final int version;
  final String name;
  final String family;
  final double referenceA4Hz;
  final double centsOffset;
  final String accidentalStyle;
  final List<int> midiNotes;
}

List<_SeedTuning> _parseTunings(String documentJson) {
  final document = jsonDecode(documentJson) as Map<String, dynamic>;
  if (document['schemaVersion'] != 1 ||
      document['pitchOrder'] != 'low_to_high') {
    throw const FormatException('Unsupported tuning seed schema.');
  }
  final tunings = (document['tunings'] as List)
      .cast<Map<String, dynamic>>()
      .map((json) {
        final notes = (json['midiNotes'] as List)
            .cast<num>()
            .map((note) => note.toInt())
            .toList();
        if (notes.length != json['stringCount'] ||
            notes.any((note) => note < 0 || note > 127)) {
          throw FormatException('Invalid string map for ${json['id']}.');
        }
        final name = json['name'] as String;
        return _SeedTuning(
          id: json['id'] as String,
          version: json['version'] as int,
          name: name,
          family: json['family'] as String,
          referenceA4Hz: (json['referenceA4Hz'] as num? ?? 440).toDouble(),
          centsOffset: (json['centsOffset'] as num? ?? 0).toDouble(),
          accidentalStyle:
              json['accidentalStyle'] as String? ??
              (name.toLowerCase().contains('flat') ? 'flat' : 'sharp'),
          midiNotes: notes,
        );
      })
      .toList();
  final keys = tunings
      .map((tuning) => '${tuning.id}@${tuning.version}')
      .toSet();
  if (keys.length != tunings.length) {
    throw const FormatException('Duplicate tuning seed key.');
  }
  return tunings;
}

List<SongTuningRecord> _parseSongs(String documentJson) {
  final document = jsonDecode(documentJson) as Map<String, dynamic>;
  if (document['schemaVersion'] != 1) {
    throw const FormatException('Unsupported song seed schema.');
  }
  final songs = (document['songs'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (json) => SongTuningRecord(
          id: json['id'] as String,
          title: json['title'] as String,
          artist: json['artist'] as String,
          searchAliases: (json['searchAliases'] as List? ?? const [])
              .cast<String>(),
          tuningId: json['tuningId'] as String,
          tuningVersion: json['tuningVersion'] as int,
          capoFret: json['capoFret'] as int,
          centsOffset: (json['centsOffset'] as num).toDouble(),
          verificationStatus: _parseVerificationStatus(
            json['verificationStatus'] as String,
          ),
          researchConfidence: _parseResearchConfidence(
            json['researchConfidence'] as String,
          ),
          sources: (json['sources'] as List)
              .cast<Map<String, dynamic>>()
              .map(_sourceFromJson)
              .toList(),
          musicBrainzRecordingMbid: json['musicBrainzRecordingMbid'] as String?,
          notes: json['notes'] as String? ?? '',
        ),
      )
      .toList();
  if (songs.map((song) => song.id).toSet().length != songs.length) {
    throw const FormatException('Duplicate song seed id.');
  }
  return songs;
}

Map<String, dynamic> _sourceToJson(SongMetadataSource source) {
  return {
    'label': source.label,
    'url': source.uri.toString(),
    'checkedAt': source.checkedAt.toIso8601String(),
    'checkedBy': source.checkedBy,
    'kind': _sourceKindValue(source.kind),
    'supports': source.supports.map(_sourceClaimValue).toList(growable: false),
  };
}

SongMetadataSource _sourceFromJson(Map<String, dynamic> json) {
  return SongMetadataSource(
    label: json['label'] as String,
    uri: Uri.parse(json['url'] as String),
    checkedAt: DateTime.parse(json['checkedAt'] as String),
    checkedBy: json['checkedBy'] as String,
    kind: _parseSourceKind(json['kind'] as String? ?? 'independent_reference'),
    supports:
        (json['supports'] as List? ??
                const ['tuning', 'capo_fret', 'cents_offset'])
            .cast<String>()
            .map(_parseSourceClaim)
            .toSet(),
  );
}

SongMetadataSourceKind _parseSourceKind(String value) => switch (value) {
  'independent_reference' => SongMetadataSourceKind.independentReference,
  'curation_oracle' => SongMetadataSourceKind.curationOracle,
  _ => throw FormatException('Unknown song source kind: $value'),
};

String _sourceKindValue(SongMetadataSourceKind value) => switch (value) {
  SongMetadataSourceKind.independentReference => 'independent_reference',
  SongMetadataSourceKind.curationOracle => 'curation_oracle',
};

SongMetadataClaim _parseSourceClaim(String value) => switch (value) {
  'tuning' => SongMetadataClaim.tuning,
  'capo_fret' => SongMetadataClaim.capoFret,
  'cents_offset' => SongMetadataClaim.centsOffset,
  _ => throw FormatException('Unknown song source claim: $value'),
};

String _sourceClaimValue(SongMetadataClaim value) => switch (value) {
  SongMetadataClaim.tuning => 'tuning',
  SongMetadataClaim.capoFret => 'capo_fret',
  SongMetadataClaim.centsOffset => 'cents_offset',
};

SongVerificationStatus _parseVerificationStatus(String value) {
  return switch (value) {
    'draft' => SongVerificationStatus.draft,
    'needs_human_review' => SongVerificationStatus.needsHumanReview,
    'verified' => SongVerificationStatus.verified,
    _ => throw FormatException('Unknown verification status: $value'),
  };
}

String _verificationStatusValue(SongVerificationStatus value) {
  return switch (value) {
    SongVerificationStatus.draft => 'draft',
    SongVerificationStatus.needsHumanReview => 'needs_human_review',
    SongVerificationStatus.verified => 'verified',
  };
}

SongResearchConfidence _parseResearchConfidence(String value) {
  return switch (value) {
    'web_verified' => SongResearchConfidence.webVerified,
    'high' => SongResearchConfidence.high,
    'medium' => SongResearchConfidence.medium,
    _ => throw FormatException('Unknown research confidence: $value'),
  };
}

String _researchConfidenceValue(SongResearchConfidence value) {
  return switch (value) {
    SongResearchConfidence.webVerified => 'web_verified',
    SongResearchConfidence.high => 'high',
    SongResearchConfidence.medium => 'medium',
  };
}

String _ftsQuery(String query) {
  final tokens = query.split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
  return tokens
      .map((token) => '"${token.replaceAll('"', '""')}"*')
      .join(' AND ');
}

String _midiLabel(int midiNote, {required bool useFlats}) {
  const sharps = [
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];
  const flats = [
    'C',
    'D♭',
    'D',
    'E♭',
    'E',
    'F',
    'G♭',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];
  final pitchClass = useFlats ? flats[midiNote % 12] : sharps[midiNote % 12];
  final octave = midiNote ~/ 12 - 1;
  return '$pitchClass$octave';
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
