import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  late Map<String, dynamic> candidates;

  setUp(() async {
    candidates =
        (jsonDecode(
                  await _workspaceFile(
                    'data/songs/candidates.v1.json',
                  ).readAsString(),
                )
                as Map)
            .cast<String, dynamic>();
  });

  test('promotes all reviewed candidates without mutating the input', () {
    final promoted = promoteSongCatalog(
      candidates: candidates,
      approvedBy: 'project-owner',
      approvedAt: DateTime.utc(2026, 7, 14),
    );
    final inputSongs = (candidates['songs'] as List)
        .cast<Map<String, dynamic>>();
    final outputSongs = (promoted['songs'] as List)
        .cast<Map<String, dynamic>>();

    expect(candidates['shippingEligible'], isFalse);
    expect(
      inputSongs.every(
        (song) => song['verificationStatus'] == 'needs_human_review',
      ),
      isTrue,
    );
    expect(promoted['shippingEligible'], isTrue);
    expect(outputSongs, hasLength(20));
    expect(
      outputSongs.every((song) => song['verificationStatus'] == 'verified'),
      isTrue,
    );
    expect(promoted['approval'], {
      'approvedBy': 'project-owner',
      'approvedAt': '2026-07-14',
      'scope': 'all_songs',
      'approvedSongCount': 20,
      'statement':
          'Project owner reviewed and approved every source-audited song.',
    });
    expect(
      outputSongs.every(
        (song) => (song['sources'] as List).every(
          (source) =>
              (source as Map)['checkedBy'] ==
              'Codex source audit; human review approved by project-owner',
        ),
      ),
      isTrue,
    );
  });

  test('rejects incomplete or non-independent approval inputs', () {
    final songs = (candidates['songs'] as List).cast<Map<String, dynamic>>();
    songs.first['sources'] = [
      songs.first['sources'][0],
      {
        ...(songs.first['sources'][0] as Map<String, dynamic>),
        'url': 'https://www.jonmaclennan.com/another-page',
      },
    ];

    expect(
      () => promoteSongCatalog(
        candidates: candidates,
        approvedBy: 'project-owner',
        approvedAt: DateTime.utc(2026, 7, 14),
      ),
      throwsArgumentError,
    );
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
