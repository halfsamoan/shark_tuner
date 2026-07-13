import 'song_tuning_record.dart';

abstract interface class SongCatalog {
  Future<List<SongTuningRecord>> search(String query);

  Future<SongTuningRecord?> getById(String id);
}
