import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final filename in ['catalog.v1.json', 'tunings.v1.json']) {
    test('bundled $filename exactly mirrors the canonical song data', () async {
      final bundled = await rootBundle.loadString('assets/songs/$filename');
      final canonical = await _workspaceFile(
        'data/songs/$filename',
      ).readAsString();

      expect(bundled, canonical);
    });
  }

  test('release catalog ships all twenty explicitly verified songs', () async {
    final bundled =
        jsonDecode(await rootBundle.loadString('assets/songs/catalog.v1.json'))
            as Map<String, dynamic>;
    final songs = bundled['songs']! as List<dynamic>;

    expect(songs, hasLength(20));
    expect(bundled['shippingEligible'], isTrue);
    expect(
      songs.every(
        (song) =>
            (song as Map<String, dynamic>)['verificationStatus'] == 'verified',
      ),
      isTrue,
    );
  });
}

File _workspaceFile(String relativePath) {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not find workspace file: $relativePath');
    }
    directory = parent;
  }
}
