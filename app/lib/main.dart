import 'package:flutter/material.dart';

import 'src/app/app_preferences.dart';
import 'src/app/bundled_font_licenses.dart';
import 'src/app/toauner_app.dart';

export 'src/app/toauner_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  final store = JsonAppPreferencesStore();
  final initialPreferences = await store.load();
  final controller = AppPreferencesController(
    initialValue: initialPreferences,
    saver: store.save,
  );
  runApp(
    ToaunerApp(
      preferencesController: controller,
      startWithStandardTuning: true,
    ),
  );
}
