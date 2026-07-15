import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:toauner_app/src/tuner/precision_tuner_screen.dart';
import 'package:toauner_app/src/tuner/reference_tone_player.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  final tuning = BuiltInTunings.standardGuitar;

  setUpAll(() async {
    await (FontLoader(
      'IBM Plex Mono',
    )..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf'))).load();
    await (FontLoader('IBM Plex Sans KR')
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansKR-Regular.ttf')))
        .load();
    await (FontLoader('JetBrains Mono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')))
        .load();
  });

  for (final themeId in const [
    SharkTuneThemeId.abyss,
    SharkTuneThemeId.paper,
    SharkTuneThemeId.clipping,
  ]) {
    testWidgets('precision tuner ${themeId.name} device-profile golden', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = _GoldenTunerEngine(tuning);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildInstrumentTheme(themeId),
          home: PrecisionTunerScreen(
            directTuning: tuning,
            directLabel: '빠른 튜닝',
            catalog: const _GoldenCatalog(),
            tunerEngineFactory: () => engine,
            referenceTonePlayerFactory: _GoldenReferenceTonePlayer.new,
            includeUnverifiedSongs: false,
            setScreenAwake: (_) async => true,
            loadInstrumentProfile: () async => null,
            saveInstrumentProfile: (_) async {},
            recordTuningHistory: (_) async {},
          ),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tuner_${themeId.name}_1080x2340.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

final class _GoldenReferenceTonePlayer implements ReferenceTonePlayer {
  @override
  Future<void> play(double frequencyHz) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _GoldenTunerEngine implements TunerEngine {
  _GoldenTunerEngine(TuningDefinition tuning)
    : _current = LiveTunerState(
        status: LiveTunerStatus.listening,
        frequencyHz: tuning.strings.first.targetFrequencyHz(
          referenceA4Hz: tuning.referenceA4Hz,
          centsOffset: tuning.centsOffset,
        ),
        clarity: 0.97,
        rmsDb: -18,
        cents: 7.2,
        target: tuning.strings.first,
        lockProgress: 0.38,
      );

  final LiveTunerState _current;

  @override
  LiveTunerState get current => _current;

  @override
  Stream<LiveTunerState> get states => const Stream.empty();

  @override
  Future<bool> hasMicrophonePermission() async => true;

  @override
  Future<void> start(TuningDefinition tuning) async {}

  @override
  Future<void> stop() async {}

  @override
  void setManualTarget(int? stringNumber) {}

  @override
  Future<void> dispose() async {}
}

final class _GoldenCatalog implements SongCatalog {
  const _GoldenCatalog();

  @override
  Future<void> close() async {}

  @override
  Future<List<SongTuningMatch>> findPlayableWith(
    TuningDefinition tuning, {
    bool includeUnverified = false,
  }) async => const [];

  @override
  Future<SongTuningMatch?> getById(
    String id, {
    bool includeUnverified = false,
  }) async => null;

  @override
  Future<List<SongTuningMatch>> search(
    String query, {
    bool includeUnverified = false,
  }) async => const [];
}
