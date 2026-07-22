import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_model.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_screen.dart';

void main() {
  testWidgets('shows local completions and clears them with confirmation', (
    tester,
  ) async {
    var saved = _ledger();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: TuningHistoryScreen(
          loader: () async => saved,
          saver: (ledger) async => saved = ledger,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('튜닝 기록'), findsWidgets);
    expect(find.text('Eruption'), findsOneWidget);
    expect(find.text('E Standard'), findsOneWidget);
    expect(find.textContaining('6현 완료'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('clear-tuning-history')));
    await tester.pumpAndSettle();
    expect(find.text('기록을 모두 지울까요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-clear-tuning-history')));
    await tester.pumpAndSettle();

    expect(saved.entries, isEmpty);
    expect(find.text('아직 완료한 튜닝이 없습니다.'), findsOneWidget);
  });
}

TuningHistoryLedger _ledger() => TuningHistoryLedger.empty()
    .record(
      TuningHistoryEntry(
        id: 'direct',
        completedAtUtc: DateTime.utc(2026, 7, 14, 9),
        tuningId: 'guitar-standard',
        tuningVersion: 1,
        tuningName: 'E Standard',
        elapsed: const Duration(seconds: 72),
        stringCount: 6,
      ),
    )
    .record(
      TuningHistoryEntry(
        id: 'song',
        completedAtUtc: DateTime.utc(2026, 7, 14, 10),
        tuningId: 'eb-standard',
        tuningVersion: 1,
        tuningName: 'E-flat Standard',
        elapsed: const Duration(seconds: 88),
        stringCount: 6,
        songId: 'eruption',
        songTitle: 'Eruption',
        artist: 'Van Halen',
      ),
    );
