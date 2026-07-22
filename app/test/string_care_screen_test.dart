import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/string_care/string_care_model.dart';
import 'package:toauner_app/src/string_care/string_care_screen.dart';

void main() {
  testWidgets('records a suggested gauge and an explicit reminder interval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ledger = StringCareLedger.empty();
    final now = DateTime(2026, 7, 14, 9);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: StringCareScreen(
          loader: () async => ledger,
          saver: (value) async => ledger = value,
          now: () => now,
          suggestedGaugeLabel: '11–56',
          suggestedTuningId: 'guitar-6-drop-c',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('설치 기록 없음'), findsOneWidget);
    expect(find.widgetWithText(TextField, '11–56'), findsOneWidget);
    await tester.tap(find.byKey(const Key('string-care-interval-60')));
    await tester.pumpAndSettle();
    expect(ledger.reminderIntervalDays, 60);

    await tester.tap(find.byKey(const Key('record-string-installation')));
    await tester.pumpAndSettle();
    expect(ledger.installations, hasLength(1));
    expect(ledger.activeInstallation!.gaugeLabel, '11–56');
    expect(ledger.activeInstallation!.tuningId, 'guitar-6-drop-c');
    expect(find.textContaining('현재 줄 0일째'), findsOneWidget);
    expect(find.textContaining('교체 알림 D-60'), findsOneWidget);
  });

  testWidgets('shows overdue status and lets the user erase local history', (
    tester,
  ) async {
    var ledger = StringCareLedger.empty()
        .withReminderIntervalDays(30)
        .recordInstallation(
          id: 'old-set',
          installedOn: DateTime.utc(2026, 6, 1),
          recordedAtUtc: DateTime.utc(2026, 6, 1),
          gaugeLabel: '10–46',
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: StringCareScreen(
          loader: () async => ledger,
          saver: (value) async => ledger = value,
          now: () => DateTime(2026, 7, 14),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('교체 알림 13일 지남'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear-string-care-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-clear-string-care')));
    await tester.pumpAndSettle();

    expect(ledger.installations, isEmpty);
    expect(ledger.reminderIntervalDays, 30);
    expect(find.text('설치 기록 없음'), findsOneWidget);
  });
}
