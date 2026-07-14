import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../songs/bundled_song_catalog.dart';
import '../songs/song_search_screen.dart';
import '../string_care/string_care_store.dart';
import '../tuner/live_tuner_engine.dart';
import 'instrument_theme.dart';

typedef SongCatalogLoader = Future<SongCatalog> Function();

class ToaunerApp extends StatelessWidget {
  const ToaunerApp({
    super.key,
    this.catalogLoader = openBundledSongCatalog,
    this.tunerEngineFactory = createLiveTunerEngine,
    this.includeUnverifiedSongs = !kReleaseMode,
    this.stringCareLoader = loadStringCareLedger,
    this.stringCareSaver = saveStringCareLedger,
    this.stringCareNow = DateTime.now,
  });

  final SongCatalogLoader catalogLoader;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;
  final StringCareLoader stringCareLoader;
  final StringCareSaver stringCareSaver;
  final DateTime Function() stringCareNow;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'toauner',
      theme: buildInstrumentTheme(),
      home: SongSearchScreen(
        catalogLoader: catalogLoader,
        tunerEngineFactory: tunerEngineFactory,
        includeUnverifiedSongs: includeUnverifiedSongs,
        stringCareLoader: stringCareLoader,
        stringCareSaver: stringCareSaver,
        stringCareNow: stringCareNow,
      ),
    );
  }
}
