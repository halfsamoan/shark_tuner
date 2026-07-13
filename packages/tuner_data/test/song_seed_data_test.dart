import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> candidates;
  late Map<String, dynamic> tuningDocument;

  setUpAll(() async {
    candidates =
        jsonDecode(
              await _workspaceFile(
                'data/songs/candidates.v1.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    tuningDocument =
        jsonDecode(
              await _workspaceFile('data/songs/tunings.v1.json').readAsString(),
            )
            as Map<String, dynamic>;
  });

  test('first curation batch has 20 unique non-shipping candidates', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();
    final ids = songs.map((song) => song['id'] as String).toSet();

    expect(candidates['shippingEligible'], isFalse);
    expect(songs, hasLength(20));
    expect(ids, hasLength(songs.length));
    expect(
      songs.every((song) => song['verificationStatus'] == 'needs_human_review'),
      isTrue,
    );
  });

  test('every song references a versioned tuning in the local catalog', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();
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
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();

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
