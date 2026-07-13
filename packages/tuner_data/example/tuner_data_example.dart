import 'package:tuner_data/tuner_data.dart';

void main() {
  final draft = SongTuningRecord(
    id: 'draft',
    title: 'Draft',
    artist: 'Unknown',
    tuningId: 'guitar-6-standard',
    tuningVersion: 1,
    verificationStatus: SongVerificationStatus.draft,
    researchConfidence: SongResearchConfidence.medium,
    sources: const [],
  );
  // ignore: avoid_print
  print(draft.title);
}
