import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuner_data/tuner_data.dart';

const _songsAsset = 'assets/songs/candidates.v1.json';
const _tuningsAsset = 'assets/songs/tunings.v1.json';

Future<SongCatalog> openBundledSongCatalog() async {
  final documents = await Future.wait([
    rootBundle.loadString(_songsAsset),
    rootBundle.loadString(_tuningsAsset),
    getApplicationSupportDirectory(),
  ]);
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
  );
}
