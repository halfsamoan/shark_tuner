import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuner_data/tuner_data.dart';

const _songsAsset = 'assets/songs/catalog.v1.json';
const _tuningsAsset = 'assets/songs/tunings.v1.json';
// (Claude) Bulk draft catalog of popular guitar songs. Merged in as unverified
// candidates: hidden from release search by the verification filter, surfaced
// only when includeUnverified is true (debug/dev builds).
const _candidatesAsset = 'assets/songs/candidates2000.v1.json';

Future<SongCatalog> openBundledSongCatalog() async {
  final documents = await Future.wait([
    rootBundle.loadString(_songsAsset),
    rootBundle.loadString(_tuningsAsset),
    getApplicationSupportDirectory(),
  ]);
  // (Claude) Tolerate a missing candidate asset so the verified catalog still loads.
  String? candidatesJson;
  try {
    candidatesJson = await rootBundle.loadString(_candidatesAsset);
  } on Object {
    candidatesJson = null;
  }
  final supportDirectory = documents[2] as Directory;
  await supportDirectory.create(recursive: true);
  final path = [
    supportDirectory.path,
    'toauner-songs-v1.sqlite',
  ].join(Platform.pathSeparator);
  return SqliteSongCatalog.open(
    path: path,
    songsDocumentJson: documents[0] as String,
    tuningsDocumentJson: documents[1] as String,
    candidateSongsDocumentJson: candidatesJson,
  );
}
