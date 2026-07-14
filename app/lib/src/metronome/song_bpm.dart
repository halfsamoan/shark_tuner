// (Claude) Loads the bundled per-song BPM index once and caches it. BPM (tempo)
// is a factual attribute, stored separately from the tuning record so the
// SongTuningRecord contract stays untouched.
import 'dart:convert';

import 'package:flutter/services.dart';

Map<String, int>? _cache;

Future<Map<String, int>> loadSongBpmIndex() async {
  final cached = _cache;
  if (cached != null) {
    return cached;
  }
  try {
    final raw = await rootBundle.loadString('assets/songs/song_bpm.v1.json');
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final byId = (doc['bpmBySongId'] as Map).cast<String, dynamic>();
    _cache = {
      for (final entry in byId.entries)
        entry.key: ((entry.value as Map)['bpm'] as num).round(),
    };
  } on Object {
    _cache = <String, int>{};
  }
  return _cache!;
}
