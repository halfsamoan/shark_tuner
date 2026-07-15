import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public platform labels use SharkTune without changing identifiers', () {
    final app = _appDirectory();
    final manifest = File(
      '${app.path}${Platform.pathSeparator}android${Platform.pathSeparator}'
      'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
      '${Platform.pathSeparator}AndroidManifest.xml',
    ).readAsStringSync();
    final plist = File(
      '${app.path}${Platform.pathSeparator}ios${Platform.pathSeparator}'
      'Runner${Platform.pathSeparator}Info.plist',
    ).readAsStringSync();
    final gradle = File(
      '${app.path}${Platform.pathSeparator}android${Platform.pathSeparator}'
      'app${Platform.pathSeparator}build.gradle.kts',
    ).readAsStringSync();

    expect(manifest, contains('android:label="SharkTune"'));
    expect(manifest, isNot(contains('android:label="toauner"')));
    expect(plist, contains('<string>SharkTune</string>'));
    expect(gradle, contains('applicationId = "app.toauner.toauner_app"'));
  });

  test('launcher, monochrome, quick tile, and widget share the brand mark', () {
    final app = _appDirectory();
    final resources = Directory(
      '${app.path}${Platform.pathSeparator}android${Platform.pathSeparator}'
      'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
      '${Platform.pathSeparator}res',
    );
    final adaptive = File(
      '${resources.path}${Platform.pathSeparator}mipmap-anydpi-v26'
      '${Platform.pathSeparator}ic_launcher.xml',
    ).readAsStringSync();
    final tile = File(
      '${resources.path}${Platform.pathSeparator}drawable'
      '${Platform.pathSeparator}ic_tile_tuner.xml',
    ).readAsStringSync();
    final widget = File(
      '${resources.path}${Platform.pathSeparator}layout'
      '${Platform.pathSeparator}tuner_widget.xml',
    ).readAsStringSync();

    expect(adaptive, contains('<monochrome'));
    expect(adaptive, contains('@drawable/ic_sharktune_mark'));
    expect(tile, contains('M204,653'));
    expect(widget, contains('@drawable/ic_sharktune_mark'));
    expect(
      File(
        '${app.path}${Platform.pathSeparator}branding'
        '${Platform.pathSeparator}sharktune-mark.svg',
      ).existsSync(),
      isTrue,
    );
  });
}

Directory _appDirectory() {
  var directory = Directory.current.absolute;
  if (File(
    '${directory.path}${Platform.pathSeparator}pubspec.yaml',
  ).readAsStringSync().contains('name: toauner_app')) {
    return directory;
  }
  return Directory('${directory.path}${Platform.pathSeparator}app');
}
