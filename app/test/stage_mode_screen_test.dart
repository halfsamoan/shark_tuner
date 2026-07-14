import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:toauner_app/src/tuner/stage_mode_screen.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  testWidgets(
    'stage mode follows detected strings and shows non-color action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final engine = _StageEngine();
      final tuning = BuiltInTunings.standardGuitar;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInstrumentTheme(),
          home: StageModeScreen(
            engine: engine,
            tuning: tuning,
            initialTarget: tuning.strings.first,
          ),
        ),
      );

      expect(find.text('E2'), findsOneWidget);
      expect(find.text('줄을 한 번 튕겨 주세요'), findsOneWidget);

      final g3 = tuning.strings.singleWhere(
        (string) => string.stringNumber == 3,
      );
      engine.emit(
        LiveTunerState(
          status: LiveTunerStatus.listening,
          target: g3,
          cents: 18.2,
          frequencyHz: g3.targetFrequencyHz(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('G3'), findsOneWidget);
      expect(find.text('+18¢'), findsOneWidget);
      expect(find.text('▼ 낮추세요'), findsOneWidget);
      expect(find.bySemanticsLabel('3번 줄 G3, 18센트 높음, 낮추세요'), findsOneWidget);

      engine.emit(
        LiveTunerState(
          status: LiveTunerStatus.listening,
          target: g3,
          cents: 0.4,
          frequencyHz: g3.targetFrequencyHz(),
          locked: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('✓ 인튠'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await engine.dispose();
      semantics.dispose();
    },
  );

  testWidgets('stage mode survives 2.0x text scale without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _StageEngine();
    final tuning = BuiltInTunings.dropC;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StageModeScreen(
            engine: engine,
            tuning: tuning,
            initialTarget: tuning.strings.first,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await engine.dispose();
  });
}

final class _StageEngine implements TunerEngine {
  final _states = StreamController<LiveTunerState>.broadcast(sync: true);
  LiveTunerState _current = LiveTunerState.idle;

  void emit(LiveTunerState state) {
    _current = state;
    _states.add(state);
  }

  @override
  LiveTunerState get current => _current;

  @override
  Stream<LiveTunerState> get states => _states.stream;

  @override
  Future<bool> hasMicrophonePermission() async => true;

  @override
  void setManualTarget(int? stringNumber) {}

  @override
  Future<void> start(TuningDefinition tuning) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _states.close();
}
