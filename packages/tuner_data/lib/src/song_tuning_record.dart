enum SongVerificationStatus { draft, needsHumanReview, verified }

final class SongMetadataSource {
  const SongMetadataSource({
    required this.label,
    required this.uri,
    required this.checkedAt,
  });

  final String label;
  final Uri uri;
  final DateTime checkedAt;
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
    required List<SongMetadataSource> sources,
    this.capoFret = 0,
    this.centsOffset = 0,
  }) : sources = List.unmodifiable(sources) {
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
    if (verificationStatus == SongVerificationStatus.verified &&
        sources.isEmpty) {
      throw ArgumentError('Verified songs require at least one source.');
    }
  }

  final String id;
  final String title;
  final String artist;
  final String tuningId;
  final int tuningVersion;
  final int capoFret;
  final double centsOffset;
  final SongVerificationStatus verificationStatus;
  final List<SongMetadataSource> sources;
}
