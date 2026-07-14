import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/stability/stability_check_screen.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  testWidgets(
    'separates observed values from cautious hypotheses after three plucks',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = _ScriptedStabilityEngine();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInstrumentTheme(),
          home: StabilityCheckScreen(
            tuning: BuiltInTunings.standardGuitar,
            engine: engine,
          ),
        ),
      );

      expect(engine.manualTargets, [6]);
      expect(find.text('판단하기 어려움'), findsOneWidget);
      expect(find.text('3회 측정 필요'), findsOneWidget);

      for (var index = 0; index < 3; index++) {
        _emitPluck(
          engine,
          sequence: index + 1,
          base: Duration(seconds: index * 3),
        );
      }
      await tester.pump();

      expect(find.text('어택 오버슈트'), findsOneWidget);
      expect(find.text('정착 시간'), findsOneWidget);
      expect(find.text('울림 중 드리프트'), findsOneWidget);
      expect(find.text('측정 기반 안내'), findsOneWidget);
      expect(find.textContaining('가능성입니다'), findsOneWidget);
      expect(find.text('결과 저장하고 닫기'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(engine.manualTargets.last, isNull);
    },
  );

  testWidgets('adds repeatability only after five same-string plucks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedStabilityEngine();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: StabilityCheckScreen(
          tuning: BuiltInTunings.standardGuitar,
          engine: engine,
        ),
      ),
    );

    for (var index = 0; index < 5; index++) {
      _emitPluck(
        engine,
        sequence: index + 1,
        base: Duration(seconds: index * 3),
        peakRmsDb: -18 + index.toDouble(),
      );
    }
    await tester.pump();

    expect(find.text('5회 재현성'), findsOneWidget);
    expect(find.text('5회 완료'), findsOneWidget);
  });
}

void _emitPluck(
  _ScriptedStabilityEngine engine, {
  required int sequence,
  required Duration base,
  double peakRmsDb = -14,
}) {
  final target = BuiltInTunings.standardGuitar.strings.first;
  for (var milliseconds = 0; milliseconds <= 2600; milliseconds += 100) {
    final elapsed = Duration(milliseconds: milliseconds);
    final cents = milliseconds <= 100
        ? 12.0
        : .4 - (milliseconds - 100) / 10000;
    engine.emit(
      LiveTunerState(
        status: LiveTunerStatus.listening,
        rawCents: cents,
        rawClarity: .98,
        rmsDb: peakRmsDb - milliseconds / 1000,
        cents: cents,
        target: target,
        audioPosition: base + elapsed,
        onsetPosition: base,
        onsetSequence: sequence,
        freshOnset: milliseconds == 0,
      ),
    );
  }
}

final class _ScriptedStabilityEngine implements TunerEngine {
  final _states = StreamController<LiveTunerState>.broadcast(sync: true);
  final manualTargets = <int?>[];
  LiveTunerState _current = const LiveTunerState(
    status: LiveTunerStatus.listening,
  );

  void emit(LiveTunerState state) {
    _current = state;
    _states.add(state);
  }

  @override
  LiveTunerState get current => _current;

  @override
  Stream<LiveTunerState> get states => _states.stream;

  @override
  Future<void> dispose() => _states.close();

  @override
  Future<bool> hasMicrophonePermission() async => true;

  @override
  void setManualTarget(int? stringNumber) => manualTargets.add(stringNumber);

  @override
  Future<void> start(TuningDefinition tuning) async {}

  @override
  Future<void> stop() async {}
}
