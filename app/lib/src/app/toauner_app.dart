import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../songs/bundled_song_catalog.dart';
import '../songs/song_search_screen.dart';
import 'instrument_theme.dart';

typedef SongCatalogLoader = Future<SongCatalog> Function();

class ToaunerApp extends StatelessWidget {
  const ToaunerApp({
    super.key,
    this.catalogLoader = openBundledSongCatalog,
    this.includeUnverifiedSongs = !kReleaseMode,
  });

  final SongCatalogLoader catalogLoader;
  final bool includeUnverifiedSongs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'toauner',
      theme: buildInstrumentTheme(),
      home: SongSearchScreen(
        catalogLoader: catalogLoader,
        includeUnverifiedSongs: includeUnverifiedSongs,
      ),
    );
  }
}
