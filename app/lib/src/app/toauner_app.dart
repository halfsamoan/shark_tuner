import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../songs/bundled_song_catalog.dart';
import '../songs/song_search_screen.dart';
import '../string_care/string_care_store.dart';
import '../tuner/live_tuner_engine.dart';
import '../tuning_history/tuning_history_store.dart';
import 'app_preferences.dart';
import 'instrument_theme.dart';

typedef SongCatalogLoader = Future<SongCatalog> Function();

class ToaunerApp extends StatefulWidget {
  const ToaunerApp({
    super.key,
    this.catalogLoader = openBundledSongCatalog,
    this.tunerEngineFactory,
    this.preferencesController,
    this.initialPreferences = const AppPreferences(hasSeenTunerPrimer: true),
    this.includeUnverifiedSongs = !kReleaseMode,
    this.stringCareLoader = loadStringCareLedger,
    this.stringCareSaver = saveStringCareLedger,
    this.stringCareNow = DateTime.now,
    this.tuningHistoryLoader = loadTuningHistoryLedger,
    this.tuningHistorySaver = saveTuningHistoryLedger,
    this.tuningHistoryRecorder = recordTuningHistoryEntry,
    this.tuningHistoryNow = DateTime.now,
  });

  final SongCatalogLoader catalogLoader;
  final TunerEngineFactory? tunerEngineFactory;
  final AppPreferencesController? preferencesController;
  final AppPreferences initialPreferences;
  final bool includeUnverifiedSongs;
  final StringCareLoader stringCareLoader;
  final StringCareSaver stringCareSaver;
  final DateTime Function() stringCareNow;
  final TuningHistoryLoader tuningHistoryLoader;
  final TuningHistorySaver tuningHistorySaver;
  final TuningHistoryRecorder tuningHistoryRecorder;
  final DateTime Function() tuningHistoryNow;

  @override
  State<ToaunerApp> createState() => _ToaunerAppState();
}

class _ToaunerAppState extends State<ToaunerApp> with WidgetsBindingObserver {
  late final AppPreferencesController _preferencesController;
  late final bool _ownsPreferencesController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsPreferencesController = widget.preferencesController == null;
    _preferencesController =
        widget.preferencesController ??
        AppPreferencesController(
          initialValue: widget.initialPreferences,
          saver: _discardPreferences,
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsPreferencesController) {
      _preferencesController.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferencesController,
      builder: (context, _) {
        final preferences = _preferencesController.value;
        final reduceMotion =
            preferences.reduceMotion ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations;
        final tunerEngineFactory =
            widget.tunerEngineFactory ??
            () => createLiveTunerEngine(
              toleranceCents: preferences.toleranceMode.holdToleranceCents,
            );
        return AppPreferencesScope(
          controller: _preferencesController,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SharkTune',
            theme: buildInstrumentTheme(preferences.themeId),
            themeAnimationDuration: reduceMotion
                ? Duration.zero
                : InstrumentMotion.instrument,
            home: SongSearchScreen(
              catalogLoader: widget.catalogLoader,
              tunerEngineFactory: tunerEngineFactory,
              includeUnverifiedSongs: widget.includeUnverifiedSongs,
              stringCareLoader: widget.stringCareLoader,
              stringCareSaver: widget.stringCareSaver,
              stringCareNow: widget.stringCareNow,
              tuningHistoryLoader: widget.tuningHistoryLoader,
              tuningHistorySaver: widget.tuningHistorySaver,
              tuningHistoryRecorder: widget.tuningHistoryRecorder,
              tuningHistoryNow: widget.tuningHistoryNow,
            ),
          ),
        );
      },
    );
  }
}

Future<void> _discardPreferences(AppPreferences _) async {}
