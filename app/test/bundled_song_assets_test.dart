import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final filename in ['candidates.v1.json', 'tunings.v1.json']) {
    test('bundled $filename exactly mirrors the canonical song data', () async {
      final bundled = await rootBundle.loadString('assets/songs/$filename');
      final canonical = await _workspaceFile(
        'data/songs/$filename',
      ).readAsString();

      expect(bundled, canonical);
    });
  }
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
