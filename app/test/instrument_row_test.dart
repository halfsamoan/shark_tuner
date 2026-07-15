import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/ui/instrument_widgets.dart';

void main() {
  testWidgets('action and toggle rows expose one 48dp mobile target', (
    tester,
  ) async {
    var actionTapped = false;
    var toggleValue = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: Scaffold(
          body: Column(
            children: [
              InstrumentActionRow(
                rowKey: const Key('action-row'),
                label: '곡 튜닝 찾기',
                detail: '곡명 · 아티스트',
                onTap: () => actionTapped = true,
              ),
              InstrumentToggleRow(
                rowKey: const Key('toggle-row'),
                label: '햅틱',
                detail: '잠금을 진동으로 알림',
                value: toggleValue,
                onChanged: (value) => toggleValue = value,
              ),
            ],
          ),
        ),
      ),
    );

    for (final key in const [Key('action-row'), Key('toggle-row')]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel('곡 튜닝 찾기, 곡명 · 아티스트'), findsOneWidget);
    expect(find.bySemanticsLabel('햅틱, 잠금을 진동으로 알림, 꺼짐'), findsOneWidget);

    await tester.tap(find.byKey(const Key('action-row')));
    await tester.tap(find.byKey(const Key('toggle-row')));

    expect(actionTapped, isTrue);
    expect(toggleValue, isTrue);
  });

  testWidgets('state panel keeps a concise message and one recovery action', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: Scaffold(
          body: InstrumentStatePanel(
            tone: InstrumentStateTone.danger,
            title: '곡을 불러올 수 없음',
            detail: '잠시 후 다시 시도',
            actionLabel: '다시 시도',
            onAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('곡을 불러올 수 없음'), findsOneWidget);
    expect(find.text('잠시 후 다시 시도'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('frequency readout distinguishes measured and target Hz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: const Scaffold(
          body: FrequencyReadout(measuredHz: 82.76, targetHz: 82.41),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('측정 주파수 82.76 Hz, 목표 82.41 Hz'),
      findsOneWidget,
    );
  });
}
