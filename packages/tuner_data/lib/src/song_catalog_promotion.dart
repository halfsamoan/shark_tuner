import 'dart:convert';

const _blockedSourceHosts = {'ultimate-guitar.com', 'songsterr.com'};

/// Promotes a source-audited candidate document after an explicit human review.
///
/// The input document is not mutated. The returned document records one batch
/// approval that applies to every song and makes the output release eligible.
Map<String, dynamic> promoteSongCatalog({
  required Map<String, dynamic> candidates,
  required String approvedBy,
  required DateTime approvedAt,
}) {
  final normalizedApprover = approvedBy.trim();
  if (normalizedApprover.isEmpty) {
    throw ArgumentError.value(approvedBy, 'approvedBy', 'Must not be empty.');
  }
  if (candidates['shippingEligible'] != false) {
    throw ArgumentError(
      'Only a non-shipping candidate document can be promoted.',
    );
  }

  final sourceSongs = (candidates['songs'] as List?)
      ?.cast<Map<String, dynamic>>();
  if (sourceSongs == null || sourceSongs.length < 20) {
    throw ArgumentError(
      'A release catalog requires at least 20 reviewed songs.',
    );
  }

  final ids = <String>{};
  final promotedSongs = <Map<String, dynamic>>[];
  for (final sourceSong in sourceSongs) {
    final song = _deepCopy(sourceSong);
    final id = song['id'] as String?;
    if (id == null || id.trim().isEmpty || !ids.add(id)) {
      throw ArgumentError('Every reviewed song needs a unique non-empty id.');
    }
    if (song['verificationStatus'] != 'needs_human_review') {
      throw ArgumentError('$id is not waiting for human review.');
    }

    final sources = (song['sources'] as List?)?.cast<Map<String, dynamic>>();
    if (sources == null || sources.length < 2) {
      throw ArgumentError('$id needs at least two sources.');
    }
    final hosts = <String>{};
    for (final source in sources) {
      final uri = Uri.tryParse(source['url'] as String? ?? '');
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw ArgumentError('$id has an invalid source URL.');
      }
      final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      if (_blockedSourceHosts.contains(host)) {
        throw ArgumentError('$id uses a prohibited source host: $host.');
      }
      hosts.add(host);
      source['checkedBy'] =
          'Codex source audit; human review approved by $normalizedApprover';
    }
    if (hosts.length < 2) {
      throw ArgumentError('$id needs two independent source hosts.');
    }

    song['verificationStatus'] = 'verified';
    promotedSongs.add(song);
  }

  final date = _formatDate(approvedAt);
  return {
    'schemaVersion': candidates['schemaVersion'],
    'generatedFrom': 'candidates.v1.json',
    'shippingEligible': true,
    'approval': {
      'approvedBy': normalizedApprover,
      'approvedAt': date,
      'scope': 'all_songs',
      'approvedSongCount': promotedSongs.length,
      'statement':
          'Project owner reviewed and approved every source-audited song.',
    },
    'songs': promotedSongs,
  };
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
  return (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
