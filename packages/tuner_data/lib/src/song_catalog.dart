import 'package:tuner_domain/tuner_domain.dart';

import 'song_tuning_match.dart';

abstract interface class SongCatalog {
  Future<List<SongTuningMatch>> search(
    String query, {
    bool includeUnverified = false,
  });

  Future<SongTuningMatch?> getById(String id, {bool includeUnverified = false});

  Future<List<SongTuningMatch>> findPlayableWith(
    TuningDefinition tuning, {
    bool includeUnverified = false,
  });

  Future<void> close();
}
