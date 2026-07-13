import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/main.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  testWidgets('searches a song and carries its exact setup into the tuner', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        includeUnverifiedSongs: true,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('곡명 또는 아티스트 검색'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Eruption');
    await _pumpFrames(tester);

    final eruptionResult = find.descendant(
      of: find.byType(InkWell),
      matching: find.text('Eruption'),
    );
    expect(eruptionResult, findsOneWidget);
    expect(find.text('Van Halen'), findsOneWidget);

    await tester.tap(eruptionResult);
    await _pumpFrames(tester);

    expect(find.text('E-flat Standard'), findsOneWidget);
    expect(find.text('+20 cents'), findsOneWidget);
    expect(find.text('사람 검증 필요'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await _pumpFrames(tester);
    await tester.tap(find.text('이 곡으로 튜닝'));
    await _pumpFrames(tester);

    expect(find.textContaining('ERUPTION'), findsOneWidget);
    expect(find.text('E♭2'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await _pumpFrames(tester);
    expect(find.textContaining('78.69 Hz'), findsNWidgets(2));
    expect(find.text('곡 기준 +20 cents 적용'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

final class _FakeSongCatalog implements SongCatalog {
  static final match = SongTuningMatch(
    song: SongTuningRecord(
      id: 'eruption-van-halen',
      title: 'Eruption',
      artist: 'Van Halen',
      tuningId: 'eb-standard',
      tuningVersion: 1,
      verificationStatus: SongVerificationStatus.needsHumanReview,
      researchConfidence: SongResearchConfidence.high,
      sources: const [],
      centsOffset: 20,
    ),
    tuning: TuningDefinition(
      id: 'eb-standard',
      version: 1,
      name: 'E-flat Standard',
      strings: const [
        TuningString(stringNumber: 6, midiNote: 39, label: 'E♭2'),
        TuningString(stringNumber: 5, midiNote: 44, label: 'A♭2'),
        TuningString(stringNumber: 4, midiNote: 49, label: 'D♭3'),
        TuningString(stringNumber: 3, midiNote: 54, label: 'G♭3'),
        TuningString(stringNumber: 2, midiNote: 58, label: 'B♭3'),
        TuningString(stringNumber: 1, midiNote: 63, label: 'E♭4'),
      ],
      centsOffset: 20,
    ),
  );

  @override
  Future<void> close() async {}

  @override
  Future<List<SongTuningMatch>> findPlayableWith(
    TuningDefinition tuning, {
    bool includeUnverified = false,
  }) async {
    return [match];
  }

  @override
  Future<SongTuningMatch?> getById(
    String id, {
    bool includeUnverified = false,
  }) async {
    return id == match.song.id ? match : null;
  }

  @override
  Future<List<SongTuningMatch>> search(
    String query, {
    bool includeUnverified = false,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    if (match.song.title.toLowerCase().contains(normalized) ||
        match.song.artist.toLowerCase().contains(normalized)) {
      return [match];
    }
    return const [];
  }
}
