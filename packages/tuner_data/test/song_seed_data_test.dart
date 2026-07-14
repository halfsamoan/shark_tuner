import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> candidates;
  late Map<String, dynamic> releaseCatalog;
  late Map<String, dynamic> tuningDocument;

  setUpAll(() async {
    candidates =
        jsonDecode(
              await _workspaceFile(
                'data/songs/candidates.v1.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    releaseCatalog =
        jsonDecode(
              await _workspaceFile('data/songs/catalog.v1.json').readAsString(),
            )
            as Map<String, dynamic>;
    tuningDocument =
        jsonDecode(
              await _workspaceFile('data/songs/tunings.v1.json').readAsString(),
            )
            as Map<String, dynamic>;
  });

  test('source-audited batch has 20 unique non-shipping candidates', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();
    final ids = songs.map((song) => song['id'] as String).toSet();

    expect(candidates['shippingEligible'], isFalse);
    expect(songs, hasLength(20));
    expect(ids, hasLength(songs.length));
    expect(
      songs.every((song) => song['verificationStatus'] == 'needs_human_review'),
      isTrue,
    );
    expect(
      songs.every((song) => song['researchConfidence'] == 'web_verified'),
      isTrue,
    );
  });

  test('project-owner approval promotes all 20 songs for release', () {
    final songs = (releaseCatalog['songs'] as List)
        .cast<Map<String, dynamic>>();
    final approval = releaseCatalog['approval'] as Map<String, dynamic>;

    expect(releaseCatalog['generatedFrom'], 'candidates.v1.json');
    expect(releaseCatalog['shippingEligible'], isTrue);
    expect(songs, hasLength(20));
    expect(
      songs.every((song) => song['verificationStatus'] == 'verified'),
      isTrue,
    );
    expect(approval['approvedBy'], 'project-owner');
    expect(approval['approvedAt'], '2026-07-14');
    expect(approval['scope'], 'all_songs');
    expect(approval['approvedSongCount'], songs.length);
  });

  test('every candidate has two distinct stored source URLs', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();

    for (final song in songs) {
      final sources = (song['sources'] as List).cast<Map<String, dynamic>>();
      final urls = sources.map((source) => source['url'] as String).toSet();
      final sourceHosts = urls.map((url) => Uri.parse(url).host).toSet();

      expect(sources, hasLength(2), reason: song['id'] as String);
      expect(urls, hasLength(2), reason: song['id'] as String);
      expect(sourceHosts, hasLength(2), reason: song['id'] as String);
      expect(
        sourceHosts.intersection({'ultimate-guitar.com', 'songsterr.com'}),
        isEmpty,
        reason: song['id'] as String,
      );
      expect(
        sources.every((source) => source['checkedAt'] == '2026-07-13'),
        isTrue,
        reason: song['id'] as String,
      );
      expect(
        sources.every(
          (source) =>
              (source['checkedBy'] as String).contains('human review pending'),
        ),
        isTrue,
        reason: song['id'] as String,
      );
    }
  });

  test('search aliases are normalized discovery metadata', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();

    for (final song in songs) {
      final aliases = (song['searchAliases'] as List).cast<String>();
      expect(aliases, isNotEmpty, reason: song['id'] as String);
      expect(
        aliases.every((alias) => alias == alias.trim() && alias.isNotEmpty),
        isTrue,
        reason: song['id'] as String,
      );
      expect(
        aliases.toSet(),
        hasLength(aliases.length),
        reason: song['id'] as String,
      );
    }

    final metallica = songs.firstWhere(
      (song) => song['id'] == 'metallica-enter-sandman',
    );
    expect(metallica['searchAliases'], contains('메탈리카'));
  });

  test('every release song keeps two human-approved independent sources', () {
    final songs = (releaseCatalog['songs'] as List)
        .cast<Map<String, dynamic>>();

    for (final song in songs) {
      final sources = (song['sources'] as List).cast<Map<String, dynamic>>();
      final urls = sources.map((source) => source['url'] as String).toSet();
      final sourceHosts = urls.map((url) => Uri.parse(url).host).toSet();

      expect(sources, hasLength(2), reason: song['id'] as String);
      expect(urls, hasLength(2), reason: song['id'] as String);
      expect(sourceHosts, hasLength(2), reason: song['id'] as String);
      expect(
        sources.every(
          (source) =>
              source['checkedBy'] ==
              'Codex source audit; human review approved by project-owner',
        ),
        isTrue,
        reason: song['id'] as String,
      );
    }
  });

  test('every song references a versioned tuning in the local catalog', () {
    final songs = (releaseCatalog['songs'] as List)
        .cast<Map<String, dynamic>>();
    final tunings = (tuningDocument['tunings'] as List)
        .cast<Map<String, dynamic>>();
    final tuningKeys = {
      for (final tuning in tunings)
        '${tuning['id']}@${tuning['version']}': tuning,
    };

    for (final song in songs) {
      final key = '${song['tuningId']}@${song['tuningVersion']}';
      expect(tuningKeys, contains(key), reason: song['id'] as String);
    }
  });

  test('tuning definitions have one valid MIDI note per physical string', () {
    final tunings = (tuningDocument['tunings'] as List)
        .cast<Map<String, dynamic>>();

    for (final tuning in tunings) {
      final notes = (tuning['midiNotes'] as List).cast<int>();
      expect(notes, hasLength(tuning['stringCount'] as int));
      expect(notes.every((note) => note >= 0 && note <= 127), isTrue);
      expect(
        notes.first,
        greaterThanOrEqualTo(29),
        reason: tuning['id'] as String,
      );
    }
  });

  test('verified entries can never ship without two stored sources', () {
    final songs = (releaseCatalog['songs'] as List)
        .cast<Map<String, dynamic>>();

    for (final song in songs.where(
      (song) => song['verificationStatus'] == 'verified',
    )) {
      expect(
        song['sources'] as List,
        hasLength(greaterThanOrEqualTo(2)),
        reason: song['id'] as String,
      );
    }
  });
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
