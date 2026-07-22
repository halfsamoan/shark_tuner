import 'package:tuner_domain/tuner_domain.dart';

import 'song_tuning_record.dart';

/// A song and the immutable, versioned tuning snapshot used by the tuner.
final class SongTuningMatch {
  const SongTuningMatch({required this.song, required this.tuning});

  final SongTuningRecord song;
  final TuningDefinition tuning;
}
