final _mbidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

const _standardDefaultGenres = {'pop', 'rock', 'country', 'folk'};

enum CurationEvidenceKind { independentReference, curationOracle }

enum CurationClaim { tuning, capoFret, centsOffset }

final class SongCurationEvidence {
  SongCurationEvidence({
    required this.label,
    required this.uri,
    required this.checkedAt,
    required this.checkedBy,
    required this.kind,
    required Set<CurationClaim> supports,
  }) : supports = Set.unmodifiable(supports) {
    if (label.trim().isEmpty || checkedBy.trim().isEmpty) {
      throw ArgumentError('Evidence label and curator must not be empty.');
    }
    if (!uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be an HTTP(S) URL.');
    }
    if (supports.isEmpty) {
      throw ArgumentError.value(supports, 'supports', 'Must not be empty.');
    }
    final host = _normalizedHost(uri);
    if (_isHostOrSubdomain(host, 'ultimate-guitar.com')) {
      throw ArgumentError.value(uri, 'uri', 'Ultimate Guitar is prohibited.');
    }
    final songsterr = _isHostOrSubdomain(host, 'songsterr.com');
    if (songsterr && kind != CurationEvidenceKind.curationOracle) {
      throw ArgumentError.value(
        kind,
        'kind',
        'Songsterr must be labeled as a curation-only oracle.',
      );
    }
    if (!songsterr && kind == CurationEvidenceKind.curationOracle) {
      throw ArgumentError.value(
        uri,
        'uri',
        'The curation oracle role is reserved for Songsterr.',
      );
    }
  }

  final String label;
  final Uri uri;
  final DateTime checkedAt;
  final String checkedBy;
  final CurationEvidenceKind kind;
  final Set<CurationClaim> supports;
}

final class SongBackboneTarget {
  SongBackboneTarget({
    required this.recordingMbid,
    this.genre,
    this.genreSourceUri,
  }) {
    _requireMbid(recordingMbid, 'recordingMbid');
    if ((genre == null) != (genreSourceUri == null)) {
      throw const FormatException(
        'genre and genreSourceUrl must be provided together.',
      );
    }
    if (genre != null && genre!.trim().isEmpty) {
      throw const FormatException('genre must not be empty.');
    }
    if (genreSourceUri != null &&
        (!genreSourceUri!.hasScheme ||
            (genreSourceUri!.scheme != 'https' &&
                genreSourceUri!.scheme != 'http'))) {
      throw const FormatException('genreSourceUrl must be HTTP(S).');
    }
  }

  final String recordingMbid;
  final String? genre;
  final Uri? genreSourceUri;
}

List<SongBackboneTarget> parseBackboneTargets(Map<String, dynamic> document) {
  if (document['schemaVersion'] != 1 || document['targets'] is! List) {
    throw const FormatException('Unsupported backbone target document.');
  }
  final targets = <SongBackboneTarget>[];
  final ids = <String>{};
  for (final raw in document['targets'] as List) {
    if (raw is! Map) {
      throw const FormatException('Every backbone target must be an object.');
    }
    final json = raw.cast<String, dynamic>();
    final recordingMbid = json['recordingMbid'];
    final genre = json['genre'];
    final genreSourceUrl = json['genreSourceUrl'];
    if (recordingMbid is! String ||
        (genre != null && genre is! String) ||
        (genreSourceUrl != null && genreSourceUrl is! String)) {
      throw const FormatException('Backbone target fields are invalid.');
    }
    final normalizedMbid = recordingMbid.toLowerCase();
    if (!ids.add(normalizedMbid)) {
      throw FormatException('Duplicate recording MBID: $normalizedMbid');
    }
    targets.add(
      SongBackboneTarget(
        recordingMbid: normalizedMbid,
        genre: (genre as String?)?.trim().toLowerCase(),
        genreSourceUri: genreSourceUrl == null
            ? null
            : Uri.tryParse(genreSourceUrl as String),
      ),
    );
  }
  if (targets.isEmpty) {
    throw const FormatException('At least one backbone target is required.');
  }
  return List.unmodifiable(targets);
}

Map<String, dynamic> buildSongCurationBackbone({
  required Iterable<Map<String, String>> canonicalRows,
  required List<SongBackboneTarget> targets,
  required Iterable<Map<String, dynamic>> popularityRows,
  required DateTime capturedAtUtc,
}) {
  if (!capturedAtUtc.isUtc) {
    throw ArgumentError.value(capturedAtUtc, 'capturedAtUtc', 'Must be UTC.');
  }
  final targetsByMbid = {
    for (final target in targets) target.recordingMbid: target,
  };
  final popularityByMbid = <String, Map<String, dynamic>>{};
  for (final row in popularityRows) {
    final rawMbid = row['recording_mbid'];
    if (rawMbid is! String) {
      throw const FormatException('Popularity row needs recording_mbid.');
    }
    final mbid = rawMbid.toLowerCase();
    _requireMbid(mbid, 'recording_mbid');
    if (popularityByMbid.containsKey(mbid)) {
      throw FormatException('Duplicate popularity MBID: $mbid');
    }
    _optionalNonNegativeInt(row['total_listen_count'], 'total_listen_count');
    _optionalNonNegativeInt(row['total_user_count'], 'total_user_count');
    popularityByMbid[mbid] = row;
  }

  final songsByMbid = <String, Map<String, dynamic>>{};
  for (final row in canonicalRows) {
    final mbid = _required(row, 'recording_mbid').toLowerCase();
    if (!targetsByMbid.containsKey(mbid)) continue;
    _requireMbid(mbid, 'recording_mbid');
    if (songsByMbid.containsKey(mbid)) {
      throw FormatException('Duplicate canonical recording MBID: $mbid');
    }
    final target = targetsByMbid[mbid]!;
    final releaseMbid = _required(row, 'release_mbid').toLowerCase();
    _requireMbid(releaseMbid, 'release_mbid');
    final artistMbids = _parseArtistMbids(_required(row, 'artist_mbids'));
    final canonicalScore = int.tryParse(_required(row, 'score'));
    if (canonicalScore == null || canonicalScore < 0) {
      throw FormatException('Invalid canonical score for $mbid.');
    }
    final popularity = popularityByMbid[mbid];
    final genre = target.genre;
    final curationState = genre == null
        ? 'identity_only'
        : _standardDefaultGenres.contains(genre)
        ? 'default_unverified'
        : 'exception_review_required';
    songsByMbid[mbid] = {
      'backboneId': 'mbrec-$mbid',
      'artist': _required(row, 'artist_credit_name'),
      'title': _required(row, 'recording_name'),
      'identity': {
        'musicBrainzRecordingMbid': mbid,
        'musicBrainzArtistMbids': artistMbids,
        'musicBrainzReleaseMbid': releaseMbid,
        'releaseName': _required(row, 'release_name'),
      },
      'priority': {
        'totalListenCount': popularity?['total_listen_count'],
        'totalUserCount': popularity?['total_user_count'],
        'canonicalScore': canonicalScore,
      },
      'curationState': curationState,
      if (genre != null) ...{
        'genre': genre,
        'genreSourceUrl': target.genreSourceUri.toString(),
      },
      if (curationState == 'default_unverified')
        'tuningProposal': {
          'tuningId': 'guitar-6-standard',
          'tuningVersion': 1,
          'confidence': 'default_unverified',
          'policyId': 'genre-standard-default-v1',
        },
    };
  }

  final missing = targetsByMbid.keys.toSet().difference(
    songsByMbid.keys.toSet(),
  );
  if (missing.isNotEmpty) {
    throw StateError(
      'Canonical snapshot is missing ${missing.length} target(s): '
      '${missing.toList()..sort()}',
    );
  }
  final songs = songsByMbid.values.toList()
    ..sort((left, right) {
      final leftPriority = left['priority'] as Map<String, dynamic>;
      final rightPriority = right['priority'] as Map<String, dynamic>;
      for (final key in [
        'totalUserCount',
        'totalListenCount',
        'canonicalScore',
      ]) {
        final comparison = ((rightPriority[key] as int?) ?? -1).compareTo(
          (leftPriority[key] as int?) ?? -1,
        );
        if (comparison != 0) return comparison;
      }
      return (left['backboneId'] as String).compareTo(
        right['backboneId'] as String,
      );
    });

  return {
    'schemaVersion': 1,
    'shippingEligible': false,
    'capturedAtUtc': capturedAtUtc.toIso8601String(),
    'sources': [
      {
        'kind': 'musicbrainz_canonical_core_snapshot',
        'license': 'CC0-1.0',
        'url': 'https://musicbrainz.org/doc/Canonical_MusicBrainz_data',
      },
      if (popularityRows.isNotEmpty)
        {
          'kind': 'listenbrainz_popularity_snapshot',
          'license': 'CC0-1.0',
          'url':
              'https://listenbrainz.readthedocs.io/en/latest/users/api/popularity.html',
        },
    ],
    'songs': songs,
  };
}

Map<String, dynamic> buildSourceAuditedSongCandidate({
  required Map<String, dynamic> backboneSong,
  required String candidateId,
  required List<String> searchAliases,
  required String tuningId,
  required int tuningVersion,
  required int capoFret,
  required double centsOffset,
  required List<SongCurationEvidence> evidence,
  required String notes,
}) {
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(candidateId)) {
    throw ArgumentError.value(candidateId, 'candidateId');
  }
  if (tuningId.trim().isEmpty || tuningVersion < 1) {
    throw ArgumentError('A versioned tuning ID is required.');
  }
  if (capoFret < 0 || capoFret > 24) {
    throw ArgumentError.value(capoFret, 'capoFret');
  }
  if (!centsOffset.isFinite || centsOffset.abs() > 100) {
    throw ArgumentError.value(centsOffset, 'centsOffset');
  }
  if (searchAliases.isEmpty ||
      searchAliases.any((alias) => alias.trim().isEmpty) ||
      searchAliases.toSet().length != searchAliases.length) {
    throw ArgumentError.value(searchAliases, 'searchAliases');
  }
  final identity = backboneSong['identity'];
  final mbid = identity is Map ? identity['musicBrainzRecordingMbid'] : null;
  if (mbid is! String) {
    throw ArgumentError('Backbone song is missing its recording MBID.');
  }
  _requireMbid(mbid, 'musicBrainzRecordingMbid');
  final title = backboneSong['title'];
  final artist = backboneSong['artist'];
  if (title is! String ||
      title.trim().isEmpty ||
      artist is! String ||
      artist.trim().isEmpty) {
    throw ArgumentError('Backbone song is missing title or artist.');
  }
  final oracleCount = evidence
      .where((item) => item.kind == CurationEvidenceKind.curationOracle)
      .length;
  if (oracleCount > 1) {
    throw ArgumentError('At most one curation oracle is allowed per song.');
  }
  for (final claim in CurationClaim.values) {
    final supporting = evidence.where((item) => item.supports.contains(claim));
    final hosts = supporting.map((item) => _normalizedHost(item.uri)).toSet();
    final independentHosts = supporting
        .where((item) => item.kind == CurationEvidenceKind.independentReference)
        .map((item) => _normalizedHost(item.uri))
        .toSet();
    if (hosts.length < 2 || independentHosts.isEmpty) {
      throw ArgumentError(
        '${_claimValue(claim)} needs two hosts including one independent source.',
      );
    }
  }
  return {
    'id': candidateId,
    'artist': artist,
    'searchAliases': searchAliases,
    'title': title,
    'musicBrainzRecordingMbid': mbid.toLowerCase(),
    'tuningId': tuningId,
    'tuningVersion': tuningVersion,
    'capoFret': capoFret,
    'centsOffset': centsOffset,
    'researchConfidence': 'web_verified',
    'verificationStatus': 'needs_human_review',
    'sources': [
      for (final source in evidence)
        {
          'label': source.label,
          'url': source.uri.toString(),
          'checkedAt': _dateValue(source.checkedAt),
          'checkedBy': source.checkedBy,
          'kind': switch (source.kind) {
            CurationEvidenceKind.independentReference =>
              'independent_reference',
            CurationEvidenceKind.curationOracle => 'curation_oracle',
          },
          'supports': source.supports.map(_claimValue).toList(growable: false),
        },
    ],
    'notes': notes,
  };
}

String _required(Map<String, String> row, String key) {
  final value = row[key]?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Canonical row is missing $key.');
  }
  return value;
}

List<String> _parseArtistMbids(String source) {
  final values = source
      .split(RegExp(r'[,;\s]+'))
      .where((value) => value.isNotEmpty)
      .map((value) => value.toLowerCase())
      .toList(growable: false);
  if (values.isEmpty) {
    throw const FormatException('artist_mbids must not be empty.');
  }
  for (final value in values) {
    _requireMbid(value, 'artist_mbids');
  }
  return values;
}

void _requireMbid(String value, String name) {
  if (!_mbidPattern.hasMatch(value)) {
    throw FormatException('$name is not a valid MBID: $value');
  }
}

void _optionalNonNegativeInt(Object? value, String name) {
  if (value != null && (value is! int || value < 0)) {
    throw FormatException('$name must be a non-negative integer or null.');
  }
}

String _normalizedHost(Uri uri) =>
    uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

bool _isHostOrSubdomain(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

String _claimValue(CurationClaim claim) => switch (claim) {
  CurationClaim.tuning => 'tuning',
  CurationClaim.capoFret => 'capo_fret',
  CurationClaim.centsOffset => 'cents_offset',
};

String _dateValue(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
