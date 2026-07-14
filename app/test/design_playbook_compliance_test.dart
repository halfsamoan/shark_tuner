import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production UI uses semantic surfaces instead of the flat chrome alias',
    () {
      final violations = _productionDartSources()
          .where(
            (source) => source.contents.contains('InstrumentColors.chrome'),
          )
          .map((source) => source.path)
          .toList();

      expect(violations, isEmpty);
    },
  );

  test('production UI contains no forbidden AI-style visual primitives', () {
    final violations = <String>[];
    for (final source in _productionDartSources()) {
      for (final forbidden in {
        '0xFF101512': 'retired single panel color',
        '0xFF33FF66': 'retired neon lock green',
        '0xFF5A6E5E': 'retired low-contrast text color',
        'BoxShadow(': 'generic drop shadow',
        'LinearGradient(': 'generic gradient',
        'RadialGradient(': 'generic gradient',
        'SweepGradient(': 'generic gradient',
      }.entries) {
        if (source.contents.contains(forbidden.key)) {
          violations.add('${source.path}: ${forbidden.value}');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('screen files do not invent colors outside the token module', () {
    final violations = _productionDartSources()
        .where((source) => !source.path.endsWith('instrument_theme.dart'))
        .where((source) => RegExp(r'\bColor\(0x').hasMatch(source.contents))
        .map((source) => source.path)
        .toList();

    expect(violations, isEmpty);
  });

  test(
    'tuner completion uses terminal glyphs instead of rounded icon fonts',
    () {
      final violations = <String>[];
      for (final source in _productionDartSources()) {
        for (final icon in [
          'Icons.check_rounded',
          'Icons.check_circle_rounded',
        ]) {
          if (source.contents.contains(icon)) {
            violations.add('${source.path}: $icon');
          }
        }
      }

      expect(violations, isEmpty);
    },
  );

  test(
    'icon fonts are limited to navigation, search, and permission affordances',
    () {
      const allowed = {
        'Icons.chevron_left_rounded',
        'Icons.search_rounded',
        'Icons.mic_rounded',
      };
      final violations = <String>[];
      final iconPattern = RegExp(r'Icons\.\w+');
      for (final source in _productionDartSources()) {
        for (final match in iconPattern.allMatches(source.contents)) {
          final icon = match.group(0)!;
          if (!allowed.contains(icon)) {
            violations.add('${source.path}: $icon');
          }
        }
      }

      expect(violations, isEmpty);
    },
  );

  test('touch UI does not expose the desktop-only Ctrl K decoration', () {
    final violations = _productionDartSources()
        .where((source) => source.contents.contains('Ctrl K'))
        .map((source) => source.path)
        .toList();

    expect(violations, isEmpty);
  });
}

List<({String path, String contents})> _productionDartSources() {
  final root = _workspaceRoot();
  final lib = Directory(
    '${root.path}${Platform.pathSeparator}app${Platform.pathSeparator}lib',
  );
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map(
        (file) => (
          path: file.path.substring(root.path.length + 1),
          contents: file.readAsStringSync(),
        ),
      )
      .toList(growable: false);
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (!_isWorkspaceRoot(directory)) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not locate the toauner workspace root.');
    }
    directory = parent;
  }
  return directory;
}

bool _isWorkspaceRoot(Directory directory) {
  final pubspec = File(
    '${directory.path}${Platform.pathSeparator}pubspec.yaml',
  );
  return pubspec.existsSync() &&
      pubspec.readAsStringSync().contains('name: toauner_workspace');
}
