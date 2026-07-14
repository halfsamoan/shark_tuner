import 'package:test/test.dart';
import 'package:tuner_data/tuner_data.dart';

void main() {
  const mbid = '11111111-1111-4111-8111-111111111111';
  final backboneSong = {
    'backboneId': 'mbrec-$mbid',
    'artist': 'Example Artist',
    'title': 'Example Song',
    'identity': {'musicBrainzRecordingMbid': mbid},
  };

  test('two independent claim sources produce only a review candidate', () {
    final candidate = buildSourceAuditedSongCandidate(
      backboneSong: backboneSong,
      candidateId: 'example-artist-example-song',
      searchAliases: const ['예시 아티스트'],
      tuningId: 'guitar-6-drop-c',
      tuningVersion: 1,
      capoFret: 0,
      centsOffset: 0,
      evidence: [
        _evidence(
          'https://en.wikipedia.org/wiki/Example_Song',
          CurationEvidenceKind.independentReference,
        ),
        _evidence(
          'https://www.songsterr.com/a/wsa/example-tab-s1',
          CurationEvidenceKind.curationOracle,
        ),
      ],
      notes: 'Two sources agree on the factual setup.',
    );

    expect(candidate['verificationStatus'], 'needs_human_review');
    expect(candidate['researchConfidence'], 'web_verified');
    expect(candidate['musicBrainzRecordingMbid'], mbid);
    final sources = (candidate['sources'] as List).cast<Map>();
    expect(sources.last['kind'], 'curation_oracle');
    expect(sources.last['supports'], ['tuning', 'capo_fret', 'cents_offset']);
  });

  test('fails when a claim lacks two hosts or an independent reference', () {
    expect(
      () => buildSourceAuditedSongCandidate(
        backboneSong: backboneSong,
        candidateId: 'example-artist-example-song',
        searchAliases: const ['Example'],
        tuningId: 'guitar-6-standard',
        tuningVersion: 1,
        capoFret: 0,
        centsOffset: 0,
        evidence: [
          _evidence(
            'https://one.example/a',
            CurationEvidenceKind.independentReference,
          ),
          _evidence(
            'https://one.example/b',
            CurationEvidenceKind.independentReference,
          ),
        ],
        notes: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => buildSourceAuditedSongCandidate(
        backboneSong: backboneSong,
        candidateId: 'example-artist-example-song',
        searchAliases: const ['Example'],
        tuningId: 'guitar-6-standard',
        tuningVersion: 1,
        capoFret: 0,
        centsOffset: 0,
        evidence: [
          _evidence(
            'https://songsterr.com/a',
            CurationEvidenceKind.curationOracle,
          ),
          _evidence(
            'https://www.songsterr.com/b',
            CurationEvidenceKind.curationOracle,
          ),
        ],
        notes: '',
      ),
      throwsArgumentError,
    );
  });

  test('blocks Ultimate Guitar and requires Songsterr oracle labeling', () {
    expect(
      () => SongCurationEvidence(
        label: 'blocked',
        uri: Uri.parse('https://tabs.ultimate-guitar.com/example'),
        checkedAt: DateTime.utc(2026, 7, 14),
        checkedBy: 'curator',
        kind: CurationEvidenceKind.independentReference,
        supports: CurationClaim.values.toSet(),
      ),
      throwsArgumentError,
    );
    expect(
      () => SongCurationEvidence(
        label: 'mislabeled',
        uri: Uri.parse('https://www.songsterr.com/a/wsa/example-tab-s1'),
        checkedAt: DateTime.utc(2026, 7, 14),
        checkedBy: 'curator',
        kind: CurationEvidenceKind.independentReference,
        supports: CurationClaim.values.toSet(),
      ),
      throwsArgumentError,
    );
  });
}

SongCurationEvidence _evidence(String uri, CurationEvidenceKind kind) =>
    SongCurationEvidence(
      label: kind.name,
      uri: Uri.parse(uri),
      checkedAt: DateTime.utc(2026, 7, 14),
      checkedBy: 'curator',
      kind: kind,
      supports: CurationClaim.values.toSet(),
    );
