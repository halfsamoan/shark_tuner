import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/app_preferences.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';

void main() {
  test('preferences encode and decode all user and local-state fields', () {
    const value = AppPreferences(
      themeId: SharkTuneThemeId.paper,
      toleranceMode: TunerToleranceMode.pro,
      hapticsEnabled: false,
      reduceMotion: true,
      hasSeenTunerPrimer: true,
      recentSearches: ['Eruption', 'Everlong'],
    );

    final decoded = decodeAppPreferences(encodeAppPreferences(value));
    expect(decoded.themeId, value.themeId);
    expect(decoded.toleranceMode, value.toleranceMode);
    expect(decoded.hapticsEnabled, isFalse);
    expect(decoded.reduceMotion, isTrue);
    expect(decoded.hasSeenTunerPrimer, isTrue);
    expect(decoded.recentSearches, value.recentSearches);
  });

  test('JSON store falls back to backup after primary corruption', () async {
    final directory = await Directory.systemTemp.createTemp('sharktune-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonAppPreferencesStore(
      directoryProvider: () async => directory,
    );
    const first = AppPreferences(themeId: SharkTuneThemeId.amber);
    const second = AppPreferences(themeId: SharkTuneThemeId.violet);
    await store.save(first);
    await store.save(second);
    await File(
      '${directory.path}${Platform.pathSeparator}app-preferences.v1.json',
    ).writeAsString('{broken');

    final recovered = await store.load();
    expect(recovered.themeId, SharkTuneThemeId.amber);
  });

  test('controller limits and de-duplicates recent searches', () async {
    AppPreferences? saved;
    final controller = AppPreferencesController(
      initialValue: const AppPreferences(),
      saver: (value) async => saved = value,
    );
    addTearDown(controller.dispose);

    for (final query in ['A', 'B', 'C', 'D', 'E', 'F', 'c']) {
      controller.recordRecentSearch(query);
    }
    await controller.flush();

    expect(controller.value.recentSearches, ['c', 'F', 'E', 'D', 'B']);
    expect(saved?.recentSearches, controller.value.recentSearches);
  });
}
