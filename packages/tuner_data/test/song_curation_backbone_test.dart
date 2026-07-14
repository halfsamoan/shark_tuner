import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  const rockMbid = '11111111-1111-4111-8111-111111111111';
  const metalMbid = '22222222-2222-4222-8222-222222222222';

  test('builds a non-shipping MBID backbone ordered by listener priority', () {
    final targets = parseBackboneTargets({
      'schemaVersion': 1,
      'targets': [
        {
          'recordingMbid': rockMbid,
          'genre': 'rock',
          'genreSourceUrl': 'https://example.com/rock-source',
        },
        {
          'recordingMbid': metalMbid,
          'genre': 'metal',
          'genreSourceUrl': 'https://example.org/metal-source',
        },
      ],
    });
    final document = buildSongCurationBackbone(
      canonicalRows: const [
        {
          'recording_mbid': rockMbid,
          'recording_name': 'Standard Song',
          'artist_credit_name': 'Rock Artist',
          'artist_mbids': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'release_mbid': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'release_name': 'Rock Record',
          'score': '80',
        },
        {
          'recording_mbid': metalMbid,
          'recording_name': 'Heavy Song',
          'artist_credit_name': 'Metal Artist',
          'artist_mbids': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'release_mbid': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          'release_name': 'Metal Record',
          'score': '90',
        },
      ],
      targets: targets,
      popularityRows: const [
        {
          'recording_mbid': rockMbid,
          'total_listen_count': 500,
          'total_user_count': 50,
        },
        {
          'recording_mbid': metalMbid,
          'total_listen_count': 1000,
          'total_user_count': 200,
        },
      ],
      capturedAtUtc: DateTime.utc(2026, 7, 14),
    );
    final songs = (document['songs'] as List).cast<Map<String, dynamic>>();

    expect(document['shippingEligible'], isFalse);
    expect(document['schemaVersion'], 1);
    expect(songs.map((song) => song['title']), ['Heavy Song', 'Standard Song']);
    expect(songs.first['curationState'], 'exception_review_required');
    expect(songs.first, isNot(contains('tuningProposal')));
    expect(songs.last['curationState'], 'default_unverified');
    expect(songs.last['tuningProposal'], {
      'tuningId': 'guitar-6-standard',
      'tuningVersion': 1,
      'confidence': 'default_unverified',
      'policyId': 'genre-standard-default-v1',
    });
    expect(songs.last['priority'], {
      'totalListenCount': 500,
      'totalUserCount': 50,
      'canonicalScore': 80,
    });
  });

  test('fails closed for malformed IDs, unproven genres, and missing rows', () {
    expect(
      () => parseBackboneTargets({
        'schemaVersion': 1,
        'targets': [
          {'recordingMbid': 'not-an-mbid'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => parseBackboneTargets({
        'schemaVersion': 1,
        'targets': [
          {'recordingMbid': rockMbid, 'genre': 'rock'},
        ],
      }),
      throwsFormatException,
    );
    final targets = parseBackboneTargets({
      'schemaVersion': 1,
      'targets': [
        {'recordingMbid': rockMbid},
      ],
    });
    expect(
      () => buildSongCurationBackbone(
        canonicalRows: const [],
        targets: targets,
        popularityRows: const [],
        capturedAtUtc: DateTime.utc(2026, 7, 14),
      ),
      throwsStateError,
    );
  });

  test('rejects duplicate targets and popularity rows', () {
    expect(
      () => parseBackboneTargets({
        'schemaVersion': 1,
        'targets': [
          {'recordingMbid': rockMbid},
          {'recordingMbid': rockMbid},
        ],
      }),
      throwsFormatException,
    );
    final targets = parseBackboneTargets({
      'schemaVersion': 1,
      'targets': [
        {'recordingMbid': rockMbid},
      ],
    });
    expect(
      () => buildSongCurationBackbone(
        canonicalRows: const [
          {
            'recording_mbid': rockMbid,
            'recording_name': 'Song',
            'artist_credit_name': 'Artist',
            'artist_mbids': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'release_mbid': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'release_name': 'Record',
            'score': '10',
          },
        ],
        targets: targets,
        popularityRows: const [
          {'recording_mbid': rockMbid},
          {'recording_mbid': rockMbid},
        ],
        capturedAtUtc: DateTime.utc(2026, 7, 14),
      ),
      throwsFormatException,
    );
  });
}
