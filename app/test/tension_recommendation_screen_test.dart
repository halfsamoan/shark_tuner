import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/string_care/string_care_model.dart';
import 'package:toauner_app/src/string_care/string_care_screen.dart';
import 'package:toauner_app/src/tension/tension_recommendation_screen.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  testWidgets('records a recommended set in the local string log', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ledger = StringCareLedger.empty();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: TensionRecommendationScreen(
          tuning: BuiltInTunings.dropC,
          stringCareLoader: () async => ledger,
          stringCareSaver: (value) async => ledger = value,
          stringCareNow: () => DateTime(2026, 7, 14, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-gauge-installation-01')));
    await tester.pumpAndSettle();

    expect(find.byType(StringCareScreen), findsOneWidget);
    expect(find.widgetWithText(TextField, '11–56'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('record-string-installation')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(StringCareScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('record-string-installation')));
    await tester.pumpAndSettle();

    expect(ledger.activeInstallation!.gaugeLabel, '11–56');
    expect(ledger.activeInstallation!.tuningId, BuiltInTunings.dropC.id);
  });

  testWidgets(
    'shows three sourced Drop C recommendations and string tensions',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInstrumentTheme(),
          home: TensionRecommendationScreen(tuning: BuiltInTunings.dropC),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('장력·게이지 추천'), findsOneWidget);
      expect(find.textContaining('DROP C'), findsWidgets);
      expect(find.byKey(const Key('gauge-recommendation-1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('gauge-recommendation-2')),
        240,
      );
      expect(find.byKey(const Key('gauge-recommendation-2')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('gauge-recommendation-3')),
        240,
      );
      expect(find.byKey(const Key('gauge-recommendation-3')), findsOneWidget);
      expect(find.textContaining('11–56'), findsWidgets);
      await tester.scrollUntilVisible(find.textContaining('현별 맞춤 단품'), 240);
      expect(find.textContaining('현별 맞춤 단품'), findsWidgets);
      await tester.scrollUntilVisible(find.textContaining('모델 v1'), 240);
      expect(find.textContaining('모델 v1'), findsOneWidget);
      expect(find.textContaining('3%'), findsOneWidget);
    },
  );

  testWidgets('accepts a user-entered current gauge profile', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: TensionRecommendationScreen(tuning: BuiltInTunings.dropD),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('custom-gauge-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-gauge-input')),
      '11-14-18-30-42-52',
    );
    await tester.tap(find.byKey(const Key('apply-custom-gauges')));
    await tester.pumpAndSettle();

    expect(find.textContaining('사용자 설정 11–52'), findsOneWidget);
    expect(find.textContaining('입력은 높은 줄 → 낮은 줄'), findsOneWidget);
    expect(find.textContaining('형식을 확인'), findsNothing);
  });

  testWidgets('rejects a custom set with the wrong number of strings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: TensionRecommendationScreen(
          tuning: BuiltInTunings.standardGuitar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('custom-gauge-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-gauge-input')),
      '10-13-17-26-36',
    );
    await tester.tap(find.byKey(const Key('apply-custom-gauges')));
    await tester.pump();

    expect(find.textContaining('6개 게이지'), findsOneWidget);
  });
}
