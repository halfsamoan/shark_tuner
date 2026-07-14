import 'package:flutter/material.dart';

import 'src/app/bundled_font_licenses.dart';
import 'src/app/toauner_app.dart';

export 'src/app/toauner_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  runApp(const ToaunerApp());
}
