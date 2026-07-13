import 'package:flutter/material.dart';

abstract final class InstrumentColors {
  static const canvas = Color(0xFF090B0D);
  static const chrome = Color(0xFF0E1114);
  static const panel = Color(0xFF13171B);
  static const raised = Color(0xFF191E23);
  static const line = Color(0xFF2A3138);
  static const text = Color(0xFFE7EBEF);
  static const muted = Color(0xFF8E99A4);
  static const accent = Color(0xFFB8F34A);
  static const accentInk = Color(0xFF111508);
  static const amber = Color(0xFFF0B84B);
  static const danger = Color(0xFFF36A6A);
}

ThemeData buildInstrumentTheme() {
  const scheme = ColorScheme.dark(
    primary: InstrumentColors.accent,
    onPrimary: InstrumentColors.accentInk,
    surface: InstrumentColors.chrome,
    onSurface: InstrumentColors.text,
    error: InstrumentColors.danger,
  );
  const outline = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: InstrumentColors.line),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: InstrumentColors.canvas,
    dividerColor: InstrumentColors.line,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: InstrumentColors.text,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      titleMedium: TextStyle(
        color: InstrumentColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: InstrumentColors.text, fontSize: 14),
      labelSmall: TextStyle(
        color: InstrumentColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: InstrumentColors.panel,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: TextStyle(color: InstrumentColors.muted, fontSize: 13),
      prefixIconColor: InstrumentColors.muted,
      suffixIconColor: InstrumentColors.muted,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: InstrumentColors.accent),
      ),
      errorBorder: outline,
      focusedErrorBorder: outline,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
