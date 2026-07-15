import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';

void main() {
  test('all six themes expose the complete semantic color contract', () {
    expect(
      SharkTuneThemes.values.keys.toSet(),
      SharkTuneThemeId.values.toSet(),
    );
    for (final id in SharkTuneThemeId.values) {
      final theme = buildInstrumentTheme(id);
      final terminal = theme.extension<TerminalTheme>();
      final selection = theme.extension<SharkTuneThemeSelection>();
      expect(terminal, isNotNull, reason: id.name);
      expect(selection?.id, id, reason: id.name);
      expect(terminal!.warning, isNot(terminal.danger), reason: id.name);
      expect(terminal.accent, isNot(terminal.successHold), reason: id.name);
      expect(theme.brightness, terminal.brightness, reason: id.name);
    }
  });

  test('Paper is light and every other production theme is dark', () {
    expect(
      buildInstrumentTheme(SharkTuneThemeId.paper).brightness,
      Brightness.light,
    );
    for (final id in const [
      SharkTuneThemeId.abyss,
      SharkTuneThemeId.onyx,
      SharkTuneThemeId.amber,
      SharkTuneThemeId.violet,
      SharkTuneThemeId.clipping,
    ]) {
      expect(buildInstrumentTheme(id).brightness, Brightness.dark);
    }
  });

  test('readable semantic colors meet text contrast on the canvas', () {
    for (final entry in SharkTuneThemes.values.entries) {
      final theme = entry.value;
      for (final color in [
        theme.ink,
        theme.inkSecondary,
        theme.textSecondary,
        theme.danger,
      ]) {
        expect(
          _contrast(color, theme.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key.name}: ${color.toARGB32().toRadixString(16)}',
        );
      }
      expect(
        _contrast(theme.accent, theme.canvas),
        greaterThanOrEqualTo(3),
        reason: '${entry.key.name}: accent',
      );
    }
  });

  test('instrument text roles use the approved IBM Plex optical scale', () {
    final text = buildInstrumentTheme().extension<InstrumentTypeTheme>();

    expect(text, isNotNull);
    expect(text!.centsHero.fontSize, 96);
    expect(text.centsHero.height, 1);
    expect(text.centsHero.fontFamily, 'IBM Plex Mono');
    expect(text.noteHero.fontSize, 52);
    expect(text.noteHero.fontFamily, 'IBM Plex Mono');
    expect(text.title.fontSize, 28);
    expect(text.title.fontFamily, 'IBM Plex Sans KR');
    expect(text.subhead.fontSize, 20);
    expect(text.body.fontSize, 16);
    expect(text.body.fontFamily, 'IBM Plex Sans KR');
    expect(text.caption.fontSize, 13);
    expect(text.status.fontSize, 11);
    expect(text.status.fontFamily, 'IBM Plex Mono');
    expect(text.status.fontFamilyFallback, contains('IBM Plex Sans KR'));
  });

  test('Figma dimension and motion handoff names resolve in Flutter', () {
    expect(InstrumentMetrics.space4, 4);
    expect(InstrumentMetrics.space8, 8);
    expect(InstrumentMetrics.space12, 12);
    expect(InstrumentMetrics.space16, 16);
    expect(InstrumentMetrics.space24, 24);
    expect(InstrumentMetrics.space32, 32);
    expect(InstrumentMetrics.radius0, 0);
    expect(InstrumentMetrics.radius2, 2);
    expect(InstrumentMetrics.radius3, 3);
    expect(InstrumentMetrics.radius4, 4);
    expect(InstrumentMetrics.strokeHairline, 1);
    expect(InstrumentMetrics.strokeEmphasis, 2);
    expect(InstrumentMotion.immediate, Duration.zero);
    expect(InstrumentMotion.instrument, const Duration(milliseconds: 140));
    expect(InstrumentMotion.lockFlash, const Duration(milliseconds: 350));
  });
}

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + .05) / (darker + .05);
}
