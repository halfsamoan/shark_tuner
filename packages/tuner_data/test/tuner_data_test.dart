import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  final firstSource = SongMetadataSource(
    label: 'Primary reference',
    uri: Uri.parse('https://example.com/primary'),
    checkedAt: DateTime.utc(2026, 7, 13),
    checkedBy: 'curator-a',
  );
  final secondSource = SongMetadataSource(
    label: 'Independent reference',
    uri: Uri.parse('https://example.org/independent'),
    checkedAt: DateTime.utc(2026, 7, 13),
    checkedBy: 'curator-b',
  );

  test('verified song metadata requires two independent sources', () {
    expect(
      () => SongTuningRecord(
        id: 'example',
        title: 'Example',
        artist: 'Example Artist',
        tuningId: 'guitar-6-standard',
        tuningVersion: 1,
        verificationStatus: SongVerificationStatus.verified,
        researchConfidence: SongResearchConfidence.webVerified,
        sources: [firstSource],
      ),
      throwsArgumentError,
    );

    final verified = SongTuningRecord(
      id: 'verified-example',
      title: 'Verified Example',
      artist: 'Example Artist',
      tuningId: 'guitar-6-standard',
      tuningVersion: 1,
      verificationStatus: SongVerificationStatus.verified,
      researchConfidence: SongResearchConfidence.webVerified,
      sources: [firstSource, secondSource],
    );

    expect(verified.sources, hasLength(2));
  });

  test('draft metadata may be stored before human verification', () {
    final song = SongTuningRecord(
      id: 'draft-example',
      title: 'Draft Example',
      artist: 'Example Artist',
      tuningId: 'guitar-6-drop-d',
      tuningVersion: 1,
      verificationStatus: SongVerificationStatus.needsHumanReview,
      researchConfidence: SongResearchConfidence.medium,
      sources: const [],
    );

    expect(song.verificationStatus, SongVerificationStatus.needsHumanReview);
  });
}
