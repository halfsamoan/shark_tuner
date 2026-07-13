import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  test('verified song metadata requires a traceable source', () {
    expect(
      () => SongTuningRecord(
        id: 'example',
        title: 'Example',
        artist: 'Example Artist',
        tuningId: 'guitar-6-standard',
        tuningVersion: 1,
        verificationStatus: SongVerificationStatus.verified,
        sources: const [],
      ),
      throwsArgumentError,
    );
  });

  test('draft metadata may be stored before human verification', () {
    final song = SongTuningRecord(
      id: 'draft-example',
      title: 'Draft Example',
      artist: 'Example Artist',
      tuningId: 'guitar-6-drop-d',
      tuningVersion: 1,
      verificationStatus: SongVerificationStatus.needsHumanReview,
      sources: const [],
    );

    expect(song.verificationStatus, SongVerificationStatus.needsHumanReview);
  });
}
