import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/main.dart';
import 'package:toauner_app/src/app/app_preferences.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/string_care/string_care_model.dart';
import 'package:toauner_app/src/string_care/string_care_screen.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:toauner_app/src/tuner/precision_tuner_screen.dart';
import 'package:toauner_app/src/tuner/reference_tone_player.dart';
import 'package:toauner_app/src/tuner/stage_mode_screen.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_model.dart';
import 'package:toauner_app/src/ui/instrument_widgets.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  testWidgets('home opens the local tuning completion history', (tester) async {
    final catalog = _FakeSongCatalog();
    final history = TuningHistoryLedger.empty().record(
      TuningHistoryEntry(
        id: 'completed-session',
        completedAtUtc: DateTime.utc(2026, 7, 14, 10),
        tuningId: 'guitar-standard',
        tuningVersion: 1,
        tuningName: 'E Standard',
        elapsed: const Duration(seconds: 75),
        stringCount: 6,
      ),
    );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
        tuningHistoryLoader: () async => history,
        tuningHistorySaver: (_) async {},
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('tool-menu-entry')));
    await tester.pumpAndSettle();
    expect(find.text('1회 완료'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tuning-history-entry')));
    await _pumpFrames(tester);
    expect(find.text('LOCAL SESSION LOG'), findsOneWidget);
    expect(find.text('6현 완료 · 1:15'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('tool menu exposes string care and opens an overdue log', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();
    final ledger = StringCareLedger.empty()
        .withReminderIntervalDays(30)
        .recordInstallation(
          id: 'old-set',
          installedOn: DateTime.utc(2026, 6, 1),
          recordedAtUtc: DateTime.utc(2026, 6, 1),
          gaugeLabel: '10–46',
        );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
        stringCareLoader: () async => ledger,
        stringCareSaver: (_) async {},
        stringCareNow: () => DateTime(2026, 7, 14),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('tool-menu-entry')));
    await tester.pumpAndSettle();
    expect(find.text('줄 관리'), findsOneWidget);
    await tester.tap(find.byKey(const Key('string-care-entry')));
    await _pumpFrames(tester);
    expect(find.byType(StringCareScreen), findsOneWidget);
    expect(find.textContaining('교체 알림 13일 지남'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('opens privacy and app information from the tool menu', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final catalog = _FakeSongCatalog();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);

    expect(find.bySemanticsLabel('도구 메뉴'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tool-menu-entry')));
    await tester.pumpAndSettle();
    expect(find.text('개인정보 및 앱 정보'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-information')));
    await _pumpFrames(tester);

    expect(find.text('개인정보 및 앱 정보'), findsOneWidget);
    expect(find.textContaining('기기 안에서 실시간으로 분석'), findsOneWidget);
    expect(find.text('설치일은 이 기기에만 저장합니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
    semantics.dispose();
  });

  testWidgets(
    'release copy audit covers home, tools, settings, privacy, song, and tuner',
    (tester) async {
      final preferences = AppPreferencesController(
        initialValue: const AppPreferences(),
        saver: (_) async {},
      );
      final catalog = _FakeSongCatalog(
        currentMatch: _FakeSongCatalog.verifiedMatch,
      );
      await tester.pumpWidget(
        ToaunerApp(
          catalogLoader: () async => catalog,
          tunerEngineFactory: _FakeTunerEngine.new,
          preferencesController: preferences,
          includeUnverifiedSongs: false,
        ),
      );
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();

      await tester.tap(find.byKey(const Key('tool-menu-entry')));
      await tester.pumpAndSettle();
      _expectNoReleaseVocabulary();
      await tester.tap(find.byKey(const Key('settings-entry')));
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();

      await tester.tap(find.byTooltip('뒤로'));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('tool-menu-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-information')));
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpFrames(tester);
      await tester.pumpWidget(
        ToaunerApp(
          catalogLoader: () async =>
              _FakeSongCatalog(currentMatch: _FakeSongCatalog.verifiedMatch),
          tunerEngineFactory: _FakeTunerEngine.new,
          preferencesController: preferences,
          includeUnverifiedSongs: false,
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.text('Eruption'),
        ),
      );
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();

      await tester.tap(find.byKey(const Key('song-tune-cta')));
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();
      await tester.tap(find.byKey(const Key('enable-microphone')));
      await _pumpFrames(tester);
      _expectNoReleaseVocabulary();

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpFrames(tester);
      preferences.dispose();
    },
  );

  testWidgets('searches a song and carries its exact setup into the tuner', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: true,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('곡명 또는 아티스트 검색'), findsOneWidget);
    final searchInput = tester.widget<EditableText>(find.byType(EditableText));
    expect(searchInput.style.color, SharkTuneThemes.abyss.text);

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
    expect(find.text('DEV·사람 검증 필요'), findsOneWidget);

    final stickyCta = find.byKey(const Key('song-tune-cta'));
    expect(stickyCta, findsOneWidget);
    expect(tester.getCenter(stickyCta).dy, lessThan(780));
    await tester.tap(stickyCta);
    await _pumpFrames(tester);

    expect(find.textContaining('ERUPTION'), findsOneWidget);
    expect(find.text('E♭2'), findsWidgets);
    expect(find.text('0.0¢'), findsOneWidget);
    expect(find.textContaining('78.69 Hz'), findsNWidgets(2));
    expect(find.text('곡 기준 +20 cents 적용'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('zero-result search offers a useful recovery path', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: true,
      ),
    );
    await _pumpFrames(tester);

    await tester.enterText(find.byType(EditableText), 'unknown song');
    await _pumpFrames(tester);

    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    expect(find.text('추천 곡'), findsOneWidget);
    expect(find.text('Eruption'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('show-all-songs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-all-songs')));
    await _pumpFrames(tester);

    final input = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.controller.text, isEmpty);
    expect(find.text('Eruption'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets(
    'search debounces input, clears it, and stores selected queries',
    (tester) async {
      final catalog = _FakeSongCatalog();
      final saved = <AppPreferences>[];
      final preferences = AppPreferencesController(
        initialValue: const AppPreferences(hasSeenTunerPrimer: true),
        saver: (value) async => saved.add(value),
      );

      await tester.pumpWidget(
        ToaunerApp(
          catalogLoader: () async => catalog,
          tunerEngineFactory: _FakeTunerEngine.new,
          preferencesController: preferences,
          includeUnverifiedSongs: true,
        ),
      );
      await _pumpFrames(tester);
      catalog.searchQueries.clear();

      await tester.enterText(find.byType(EditableText), 'E');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(EditableText), 'Eruption');
      await tester.pump(const Duration(milliseconds: 249));
      expect(catalog.searchQueries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(catalog.searchQueries, ['Eruption']);

      await tester.tap(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.text('Eruption'),
        ),
      );
      await _pumpFrames(tester);
      expect(preferences.value.recentSearches, ['Eruption']);
      expect(saved.last.recentSearches, ['Eruption']);

      await tester.tap(find.byTooltip('뒤로'));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('clear-song-search')));
      await _pumpFrames(tester);
      expect(find.byKey(const Key('recent-search-Eruption')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-recent-searches')));
      await tester.pump();
      expect(preferences.value.recentSearches, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpFrames(tester);
      preferences.dispose();
    },
  );

  testWidgets('settings changes theme, tolerance, haptics, and motion', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();
    final preferences = AppPreferencesController(
      initialValue: const AppPreferences(hasSeenTunerPrimer: true),
      saver: (_) async {},
    );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        preferencesController: preferences,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('tool-menu-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-entry')));
    await _pumpFrames(tester);

    await tester.ensureVisible(find.byKey(const Key('theme-paper')));
    await tester.tap(find.byKey(const Key('theme-paper')));
    await _pumpFrames(tester);
    expect(preferences.value.themeId, SharkTuneThemeId.paper);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.brightness, Brightness.light);

    await tester.ensureVisible(find.byKey(const Key('tolerance-pro')));
    await tester.tap(find.byKey(const Key('tolerance-pro')));
    await tester.pump();
    expect(preferences.value.toleranceMode, TunerToleranceMode.pro);

    await tester.ensureVisible(find.byKey(const Key('haptics-toggle')));
    await tester.tap(find.byKey(const Key('haptics-toggle')));
    await tester.pump();
    expect(preferences.value.hapticsEnabled, isFalse);

    await tester.ensureVisible(find.byKey(const Key('reduce-motion-toggle')));
    await tester.tap(find.byKey(const Key('reduce-motion-toggle')));
    await tester.pump();
    expect(preferences.value.reduceMotion, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
    preferences.dispose();
  });

  testWidgets('system accessibility motion reduction overrides app motion', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => _FakeSongCatalog(),
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);

    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      InstrumentMotion.instrument,
    );

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      Duration.zero,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('user motion preference removes instrument transitions', (
    tester,
  ) async {
    final preferences = AppPreferencesController(
      initialValue: const AppPreferences(hasSeenTunerPrimer: true),
      saver: (_) async {},
    );
    await tester.pumpWidget(
      AppPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          theme: buildInstrumentTheme(),
          home: const Scaffold(
            body: TuningNoteCell(label: 'E2', stringNumber: 6),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      InstrumentMotion.instrument,
    );
    preferences.setReduceMotion(true);
    await tester.pump();
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    preferences.dispose();
  });

  testWidgets('opens gauge recommendations from a song setup', (tester) async {
    final catalog = _FakeSongCatalog();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: true,
      ),
    );
    await _pumpFrames(tester);
    await tester.enterText(find.byType(EditableText), 'Eruption');
    await _pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Eruption'),
      ),
    );
    await _pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('gauge-recommendation-cta')),
      240,
    );
    await tester.tap(find.byKey(const Key('gauge-recommendation-cta')));
    await _pumpFrames(tester);

    expect(find.text('장력·게이지 추천'), findsOneWidget);
    expect(find.textContaining('E-FLAT STANDARD'), findsWidgets);
    expect(find.byKey(const Key('gauge-recommendation-1')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('opens the standard tuner without choosing a song', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: () => engine,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('quick-tune-standard')));
    await _pumpFrames(tester);

    expect(find.textContaining('바로 튜닝'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('STANDARD'), findsWidgets);
    expect(find.text('E2'), findsWidgets);
    expect(find.text('곡을 선택하지 않아도 튜닝할 수 있습니다.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('opens E-flat as a progressive direct-tuning target', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: () => engine,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('quick-tune-eb')));
    await _pumpFrames(tester);

    expect(find.textContaining('E-FLAT STANDARD'), findsWidgets);
    expect(engine.startedTunings, ['guitar-6-eb-standard']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('direct tuning picker exposes lower and modal presets', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog();
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: () => engine,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('quick-tune-more')));
    await tester.pumpAndSettle();
    expect(find.text('D Standard'), findsOneWidget);
    expect(find.text('Drop C-sharp'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('direct-tuning-guitar-6-d-standard')),
    );
    await _pumpFrames(tester);

    expect(engine.startedTunings, ['guitar-6-d-standard']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('release tuner hides telemetry and never scrolls vertically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = _FakeSongCatalog(
      currentMatch: _FakeSongCatalog.verifiedMatch,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: catalog,
          tunerEngineFactory: _FakeTunerEngine.new,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    for (final internalCopy in [
      'FTS5',
      'UNPROCESSED',
      'VOICE_RECOGNITION',
      'DSP',
      'isolate',
      'samples',
      'DEVELOPMENT',
      '사람 검증 필요',
    ]) {
      expect(find.textContaining(internalCopy), findsNothing);
    }
    final statusBar = tester.widget<InstrumentStatusBar>(
      find.byType(InstrumentStatusBar),
    );
    expect(statusBar.state, '인튠');
    expect(find.byKey(const Key('dev-diagnostics')), findsNothing);

    final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
    expect(scrollables, isNotEmpty);
    expect(
      scrollables.every(
        (scrollable) =>
            scrollable.axisDirection == AxisDirection.left ||
            scrollable.axisDirection == AxisDirection.right,
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('song-first flow survives the required 1.3x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final catalog = _FakeSongCatalog(
      currentMatch: _FakeSongCatalog.verifiedMatch,
    );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('곡명 또는 아티스트 검색'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Eruption');
    await _pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Eruption'),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('E-flat Standard'), findsOneWidget);
    expect(find.byKey(const Key('song-tune-cta')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('live tuner remains usable at 2.0x text scale', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: _FakeTunerEngine.new,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(PitchTape), findsOneWidget);
    expect(find.text('0.0¢'), findsOneWidget);
    expect(find.byType(TuningNoteCell), findsNWidgets(6));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('Clipping uses its dedicated live-tuner frame', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(SharkTuneThemeId.clipping),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: _FakeTunerEngine.new,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('clipping-tuner-skin')), findsOneWidget);
    expect(find.text('CLIP//LIVE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('release song flow exposes trust without internal vocabulary', (
    tester,
  ) async {
    final catalog = _FakeSongCatalog(
      currentMatch: _FakeSongCatalog.verifiedMatch,
    );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: _FakeTunerEngine.new,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);
    await tester.enterText(find.byType(EditableText), 'Eruption');
    await _pumpFrames(tester);
    final eruptionResult = find.descendant(
      of: find.byType(InkWell),
      matching: find.text('Eruption'),
    );
    await tester.tap(eruptionResult);
    await _pumpFrames(tester);

    expect(find.text('검증된 튜닝 ✓'), findsWidgets);
    for (final internalCopy in [
      '버전',
      '@1',
      'DEV·',
      '사람 검증',
      '출처 확인 전 후보',
      'FTS5',
      'UNPROCESSED',
      'VOICE_RECOGNITION',
      'DSP',
      'isolate',
      'samples',
      'DEVELOPMENT',
    ]) {
      expect(find.textContaining(internalCopy), findsNothing);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('guides peg action, marks locks, and advances all six strings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = _FakeSongCatalog(
      currentMatch: _FakeSongCatalog.verifiedMatch,
    );
    final engine = _ScriptedTunerEngine();
    final historyEntries = <TuningHistoryEntry>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: catalog,
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
          recordTuningHistory: (entry) async => historyEntries.add(entry),
          tuningHistoryNow: () => DateTime.utc(2026, 7, 14, 10, 30),
        ),
      ),
    );
    await _pumpFrames(tester);

    engine.emit(_stateForString(6, cents: 24));
    await tester.pump();
    expect(
      find.text('음이 높아요'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.textContaining('6번 줄 페그를 풀어 낮추세요'), findsOneWidget);
    expect(find.text('−50  ♭'), findsNothing);
    expect(find.byType(PitchTape), findsOneWidget);

    for (final stringNumber in [6, 5, 4, 3, 2, 1]) {
      engine.emit(_stateForString(stringNumber, cents: 0, locked: true));
      await tester.pump();
      expect(find.text('$stringNumber번 줄 완료'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
    }
    await tester.pumpAndSettle();

    expect(find.text('6현 모두 완료!'), findsOneWidget);
    expect(find.text('이 튜닝으로 연주 가능한 곡 1개'), findsOneWidget);
    expect(engine.manualTargets, isEmpty);
    expect(find.byKey(const Key('tune-complete-glyph')), findsOneWidget);
    expect(find.byKey(const Key('open-stability-check')), findsOneWidget);
    expect(historyEntries, hasLength(1));
    expect(historyEntries.single.tuningId, 'eb-standard');
    expect(historyEntries.single.songTitle, 'Eruption');
    expect(historyEntries.single.artist, 'Van Halen');
    expect(historyEntries.single.stringCount, 6);

    engine.emit(_stateForString(1, cents: 0, locked: true));
    await tester.pump();
    expect(historyEntries, hasLength(1));

    await tester.tap(find.byKey(const Key('open-stability-check')));
    await tester.pumpAndSettle();
    expect(find.text('줄이 맞은 뒤에도 흔들리는지 확인합니다.'), findsOneWidget);
    expect(engine.manualTargets, [6]);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(engine.manualTargets, [6, null]);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('manual string focus exposes a clear return to auto detection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    final sixthStringChip = find.byWidgetPredicate(
      (widget) => widget is TuningNoteCell && widget.stringNumber == 6,
    );
    await tester.tap(sixthStringChip);
    await tester.pump();
    expect(find.textContaining('직접 선택'), findsOneWidget);
    expect(find.byKey(const Key('resume-auto-detection')), findsOneWidget);
    expect(engine.manualTargets, [6]);

    engine.emit(_stateForString(3, cents: -12));
    await tester.pump();
    expect(find.textContaining('E♭2 · 6번 줄 · 직접 선택'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resume-auto-detection')));
    await tester.pump();
    expect(engine.manualTargets, [6, null]);
    engine.emit(_stateForString(3, cents: -12));
    await tester.pump();
    expect(find.textContaining('G♭3 · 3번 줄 · 자동 인식'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('manual focus explains when a different string is heard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    final sixthString = _FakeSongCatalog.match.tuning.strings.first;
    final thirdString = _FakeSongCatalog.match.tuning.strings.singleWhere(
      (string) => string.stringNumber == 3,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is TuningNoteCell && widget.stringNumber == 6,
      ),
    );
    await tester.pump();
    engine.emit(
      LiveTunerState(
        status: LiveTunerStatus.listening,
        frequencyHz: thirdString.targetFrequencyHz(
          referenceA4Hz: _FakeSongCatalog.match.tuning.referenceA4Hz,
          centsOffset: _FakeSongCatalog.match.tuning.centsOffset,
        ),
        clarity: 0.99,
        rmsDb: -12,
        cents: 900,
        target: sixthString,
        heardTarget: thirdString,
      ),
    );
    await tester.pump();

    expect(find.text('3번 줄 소리가 들려요'), findsOneWidget);
    expect(find.text('6번 줄을 튕겨 주세요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('primes microphone use before requesting permission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine(permissionGranted: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(engine.startedTunings, isEmpty);
    expect(find.text('줄 소리를 듣고 음정을 측정해요'), findsOneWidget);
    expect(find.textContaining('소리는 기기에서만 분석되고 저장되지 않습니다'), findsOneWidget);

    await tester.tap(find.byKey(const Key('enable-microphone')));
    await _pumpFrames(tester);
    expect(engine.startedTunings, [_FakeSongCatalog.match.tuning.id]);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('shows the first-tune primer once even with permission granted', (
    tester,
  ) async {
    final engine = _ScriptedTunerEngine();
    final preferences = AppPreferencesController(
      initialValue: const AppPreferences(),
      saver: (_) async {},
    );

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => _FakeSongCatalog(),
        tunerEngineFactory: () => engine,
        preferencesController: preferences,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('quick-tune-standard')));
    await _pumpFrames(tester);

    expect(find.text('마이크 사용 안내'), findsOneWidget);
    expect(engine.startedTunings, isEmpty);
    await tester.tap(find.byKey(const Key('enable-microphone')));
    await _pumpFrames(tester);
    expect(preferences.value.hasSeenTunerPrimer, isTrue);
    expect(engine.startedTunings, ['guitar-6-standard']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
    preferences.dispose();
  });

  testWidgets('microphone denial offers a working app settings action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();
    var settingsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
          openAppSettings: () async {
            settingsOpened = true;
            return true;
          },
        ),
      ),
    );
    await _pumpFrames(tester);
    engine.emit(const LiveTunerState(status: LiveTunerStatus.permissionDenied));
    await tester.pump();

    expect(find.text('설정에서 마이크를 허용해 주세요.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-app-settings')));
    await tester.pump();
    expect(settingsOpened, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('peg setup adds a physical rotation direction to guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();
    InstrumentPegProfile? savedProfile;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
          loadInstrumentProfile: () async => null,
          saveInstrumentProfile: (profile) async {
            savedProfile = profile;
          },
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('configure-peg-guidance')), findsOneWidget);
    await tester.tap(find.byKey(const Key('configure-peg-guidance')));
    await tester.pumpAndSettle();
    expect(find.text('내 기타 페그 설정'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-peg-profile')));
    await tester.pumpAndSettle();

    expect(savedProfile, isNotNull);
    expect(savedProfile!.layout, HeadstockLayout.split);
    engine.emit(_stateForString(6, cents: -24));
    await tester.pump();
    expect(find.textContaining('↺ 반시계방향'), findsOneWidget);
    expect(find.textContaining('헤드스톡 정면에서'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('two opposite peg outcomes pause and offer a persisted flip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();
    final saves = <InstrumentPegProfile>[];
    final profile = InstrumentPegProfile.split(
      stringCount: 6,
      bassSideStringCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
          loadInstrumentProfile: () async => profile,
          saveInstrumentProfile: (profile) async => saves.add(profile),
        ),
      ),
    );
    await _pumpFrames(tester);

    engine.emit(_stateForString(6, cents: -20));
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify-peg-direction')));
    await tester.pump();
    engine.emit(_stateForString(6, cents: -26));
    await tester.pump();
    expect(find.text('방향 안내를 멈췄어요'), findsNothing);

    await tester.tap(find.byKey(const Key('verify-peg-direction')));
    await tester.pump();
    engine.emit(_stateForString(6, cents: -32));
    await tester.pump();
    expect(find.text('방향 안내를 멈췄어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept-peg-direction-flip')));
    await tester.pump();
    expect(saves, hasLength(1));
    expect(saves.single.directionOverrides[6], PegRotationDirection.clockwise);
    expect(find.textContaining('↻ 시계방향'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('classical slotted peg is calibrated before direction advice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();
    final saves = <InstrumentPegProfile>[];
    final profile = InstrumentPegProfile.classicalSplit(
      stringCount: 6,
      bassSideStringCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          includeUnverifiedSongs: false,
          loadInstrumentProfile: () async => profile,
          saveInstrumentProfile: (profile) async => saves.add(profile),
        ),
      ),
    );
    await _pumpFrames(tester);

    engine.emit(_stateForString(6, cents: -20));
    await tester.pump();
    expect(find.textContaining('클래식 페그 방향 확인'), findsOneWidget);
    expect(find.textContaining('반시계방향'), findsNothing);

    await tester.tap(find.byKey(const Key('verify-peg-direction')));
    await tester.pump();
    engine.emit(_stateForString(6, cents: -14));
    await tester.pump();
    expect(saves, hasLength(1));
    expect(saves.single.directionOverrides[6], PegRotationDirection.clockwise);
    expect(find.textContaining('↻ 시계방향'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('keeps the screen awake only while the tuner is mounted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final awakeStates = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: _ScriptedTunerEngine.new,
          includeUnverifiedSongs: false,
          setScreenAwake: (enabled) async {
            awakeStates.add(enabled);
            return true;
          },
        ),
      ),
    );
    await _pumpFrames(tester);
    expect(awakeStates, [true]);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
    expect(awakeStates, [true, false]);
  });

  testWidgets('opens stage mode on the existing tuner engine', (tester) async {
    final catalog = _FakeSongCatalog();
    final engine = _ScriptedTunerEngine();

    await tester.pumpWidget(
      ToaunerApp(
        catalogLoader: () async => catalog,
        tunerEngineFactory: () => engine,
        includeUnverifiedSongs: false,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('quick-tune-standard')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('open-stage-mode')));
    await _pumpFrames(tester);
    expect(find.byType(StageModeScreen), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(engine.startedTunings, ['guitar-6-standard']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
  });

  testWidgets('reference tone pauses capture and follows the selected string', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _ScriptedTunerEngine();
    final player = _FakeReferenceTonePlayer();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: PrecisionTunerScreen(
          match: _FakeSongCatalog.verifiedMatch,
          catalog: _FakeSongCatalog(
            currentMatch: _FakeSongCatalog.verifiedMatch,
          ),
          tunerEngineFactory: () => engine,
          referenceTonePlayerFactory: () => player,
          includeUnverifiedSongs: false,
        ),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('reference-tone-toggle')));
    await _pumpFrames(tester);
    expect(engine.stopCount, 1);
    expect(player.playedFrequencies, hasLength(1));
    expect(player.playedFrequencies.single, closeTo(78.69, 0.01));
    expect(find.textContaining('REF E♭2 정지'), findsOneWidget);

    await tester.tap(find.text('E♭4').first);
    await _pumpFrames(tester);
    expect(player.playedFrequencies, hasLength(2));
    final highTarget = _FakeSongCatalog.match.tuning.strings
        .singleWhere((string) => string.stringNumber == 1)
        .targetFrequencyHz(
          referenceA4Hz: _FakeSongCatalog.match.tuning.referenceA4Hz,
          centsOffset: _FakeSongCatalog.match.tuning.centsOffset,
        );
    expect(player.playedFrequencies.last, closeTo(highTarget, 0.001));

    await tester.tap(find.byKey(const Key('reference-tone-toggle')));
    await _pumpFrames(tester);
    expect(player.stopCount, 1);
    expect(engine.startedTunings, ['eb-standard', 'eb-standard']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFrames(tester);
    expect(player.disposed, isTrue);
  });
}

LiveTunerState _stateForString(
  int stringNumber, {
  required double cents,
  bool locked = false,
}) {
  final target = _FakeSongCatalog.match.tuning.strings.singleWhere(
    (string) => string.stringNumber == stringNumber,
  );
  final targetHz = target.targetFrequencyHz(
    referenceA4Hz: _FakeSongCatalog.match.tuning.referenceA4Hz,
    centsOffset: _FakeSongCatalog.match.tuning.centsOffset,
  );
  return LiveTunerState(
    status: LiveTunerStatus.listening,
    frequencyHz: targetHz,
    clarity: 0.99,
    rmsDb: -12,
    cents: cents,
    target: target,
    locked: locked,
    lockProgress: locked ? 1 : 0,
    actualSampleRate: 48000,
    windowSamples: 4096,
  );
}

final class _FakeTunerEngine implements TunerEngine {
  _FakeTunerEngine() {
    final match = _FakeSongCatalog.match;
    final target = match.tuning.strings.first;
    _current = LiveTunerState(
      status: LiveTunerStatus.listening,
      frequencyHz: target.targetFrequencyHz(
        referenceA4Hz: match.tuning.referenceA4Hz,
        centsOffset: match.tuning.centsOffset,
      ),
      clarity: 0.99,
      rmsDb: -12,
      cents: 0,
      target: target,
      locked: true,
      lockProgress: 1,
      actualSampleRate: 48000,
      windowSamples: 8192,
      processingDuration: const Duration(milliseconds: 2),
    );
  }

  late LiveTunerState _current;

  @override
  LiveTunerState get current => _current;

  @override
  Stream<LiveTunerState> get states => const Stream.empty();

  @override
  Future<bool> hasMicrophonePermission() async => true;

  @override
  Future<void> dispose() async {}

  @override
  void setManualTarget(int? stringNumber) {}

  @override
  Future<void> start(TuningDefinition tuning) async {}

  @override
  Future<void> stop() async {}
}

final class _ScriptedTunerEngine implements TunerEngine {
  _ScriptedTunerEngine({this.permissionGranted = true});

  final bool permissionGranted;
  final _states = StreamController<LiveTunerState>.broadcast(sync: true);
  final manualTargets = <int?>[];
  final startedTunings = <String>[];
  int stopCount = 0;
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
  Future<bool> hasMicrophonePermission() async => permissionGranted;

  @override
  Future<void> dispose() => _states.close();

  @override
  void setManualTarget(int? stringNumber) {
    manualTargets.add(stringNumber);
  }

  @override
  Future<void> start(TuningDefinition tuning) async {
    startedTunings.add(tuning.id);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

final class _FakeReferenceTonePlayer implements ReferenceTonePlayer {
  final playedFrequencies = <double>[];
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<void> play(double frequencyHz) async {
    playedFrequencies.add(frequencyHz);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void _expectNoReleaseVocabulary() {
  for (final internalCopy in const [
    'toauner',
    'FTS5',
    'UNPROCESSED',
    'VOICE_RECOGNITION',
    'DSP',
    'isolate',
    'samples',
    'DEVELOPMENT',
    'DEV·',
    '사람 검증 필요',
    '출처 확인 전 후보',
  ]) {
    expect(find.textContaining(internalCopy), findsNothing);
  }
}

final class _FakeSongCatalog implements SongCatalog {
  _FakeSongCatalog({SongTuningMatch? currentMatch})
    : currentMatch = currentMatch ?? match;

  final SongTuningMatch currentMatch;
  final List<String> searchQueries = [];

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

  static final verifiedMatch = SongTuningMatch(
    song: SongTuningRecord(
      id: 'eruption-van-halen-verified',
      title: 'Eruption',
      artist: 'Van Halen',
      tuningId: 'eb-standard',
      tuningVersion: 1,
      verificationStatus: SongVerificationStatus.verified,
      researchConfidence: SongResearchConfidence.webVerified,
      sources: [
        SongMetadataSource(
          label: 'Source A',
          uri: Uri.parse('https://example.com/a'),
          checkedAt: DateTime.utc(2026, 7, 14),
          checkedBy: 'project-owner',
        ),
        SongMetadataSource(
          label: 'Source B',
          uri: Uri.parse('https://example.org/b'),
          checkedAt: DateTime.utc(2026, 7, 14),
          checkedBy: 'project-owner',
        ),
      ],
      centsOffset: 20,
    ),
    tuning: match.tuning,
  );

  @override
  Future<void> close() async {}

  @override
  Future<List<SongTuningMatch>> findPlayableWith(
    TuningDefinition tuning, {
    bool includeUnverified = false,
  }) async {
    return [currentMatch];
  }

  @override
  Future<SongTuningMatch?> getById(
    String id, {
    bool includeUnverified = false,
  }) async {
    return id == currentMatch.song.id ? currentMatch : null;
  }

  @override
  Future<List<SongTuningMatch>> search(
    String query, {
    bool includeUnverified = false,
  }) async {
    searchQueries.add(query);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return [currentMatch];
    }
    if (currentMatch.song.title.toLowerCase().contains(normalized) ||
        currentMatch.song.artist.toLowerCase().contains(normalized)) {
      return [currentMatch];
    }
    return const [];
  }
}
