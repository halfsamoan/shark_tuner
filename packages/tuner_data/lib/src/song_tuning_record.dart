enum SongVerificationStatus { draft, needsHumanReview, verified }

enum SongResearchConfidence { webVerified, high, medium }

enum SongMetadataSourceKind { independentReference, curationOracle }

enum SongMetadataClaim { tuning, capoFret, centsOffset }

final class SongMetadataSource {
  SongMetadataSource({
    required this.label,
    required this.uri,
    required this.checkedAt,
    required this.checkedBy,
    this.kind = SongMetadataSourceKind.independentReference,
    Set<SongMetadataClaim> supports = const {
      SongMetadataClaim.tuning,
      SongMetadataClaim.capoFret,
      SongMetadataClaim.centsOffset,
    },
  }) : supports = Set.unmodifiable(supports) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'Must not be empty.');
    }
    if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError.value(uri, 'uri', 'Must be an HTTP(S) URI.');
    }
    if (checkedBy.trim().isEmpty) {
      throw ArgumentError.value(checkedBy, 'checkedBy', 'Must not be empty.');
    }
    if (supports.isEmpty) {
      throw ArgumentError.value(supports, 'supports', 'Must not be empty.');
    }
  }

  final String label;
  final Uri uri;
  final DateTime checkedAt;
  final String checkedBy;
  final SongMetadataSourceKind kind;
  final Set<SongMetadataClaim> supports;
}

/// Factual song-to-tuning metadata. It must never contain tabs or lyrics.
final class SongTuningRecord {
  SongTuningRecord({
    required this.id,
    required this.title,
    required this.artist,
    required this.tuningId,
    required this.tuningVersion,
    required this.verificationStatus,
    required this.researchConfidence,
    required List<SongMetadataSource> sources,
    List<String> searchAliases = const [],
    this.capoFret = 0,
    this.centsOffset = 0,
    this.notes = '',
    this.musicBrainzRecordingMbid,
  }) : searchAliases = _normalizeSearchAliases(searchAliases),
       sources = List.unmodifiable(sources) {
    if (id.trim().isEmpty || title.trim().isEmpty || artist.trim().isEmpty) {
      throw ArgumentError('Song id, title, and artist must not be empty.');
    }
    if (tuningId.trim().isEmpty || tuningVersion <= 0) {
      throw ArgumentError('A versioned tuning reference is required.');
    }
    if (capoFret < 0 || capoFret > 24) {
      throw ArgumentError.value(capoFret, 'capoFret');
    }
    if (!centsOffset.isFinite || centsOffset.abs() > 100) {
      throw ArgumentError.value(centsOffset, 'centsOffset');
    }
    final mbid = musicBrainzRecordingMbid;
    if (mbid != null && !_mbidPattern.hasMatch(mbid)) {
      throw ArgumentError.value(mbid, 'musicBrainzRecordingMbid');
    }
    if (verificationStatus == SongVerificationStatus.verified) {
      final independentUris = sources.map((source) => source.uri).toSet();
      if (independentUris.length < 2) {
        throw ArgumentError(
          'Verified songs require at least two distinct sources.',
        );
      }
    }
  }

  final String id;
  final String title;
  final String artist;
  final List<String> searchAliases;
  final String tuningId;
  final int tuningVersion;
  final int capoFret;
  final double centsOffset;
  final SongVerificationStatus verificationStatus;
  final SongResearchConfidence researchConfidence;
  final List<SongMetadataSource> sources;
  final String notes;
  final String? musicBrainzRecordingMbid;
}

final _mbidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

List<String> _normalizeSearchAliases(List<String> aliases) {
  final normalized = aliases.map((alias) => alias.trim()).toList();
  if (normalized.any((alias) => alias.isEmpty)) {
    throw ArgumentError.value(aliases, 'searchAliases', 'Must not be empty.');
  }
  if (normalized.toSet().length != normalized.length) {
    throw ArgumentError.value(aliases, 'searchAliases', 'Must be unique.');
  }
  return List.unmodifiable(normalized);
}
