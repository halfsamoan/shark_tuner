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

  test('readable semantic colors remain visible on every working surface', () {
    for (final entry in SharkTuneThemes.values.entries) {
      final theme = entry.value;
      final surfaces = <String, Color>{
        'canvas': theme.canvas,
        'panel': theme.panel,
        'raised': theme.raised,
        'header': theme.header,
      };
      final readableColors = <String, Color>{
        'ink': theme.ink,
        'inkSecondary': theme.inkSecondary,
        'textSecondary': theme.textSecondary,
      };
      for (final surface in surfaces.entries) {
        for (final readable in readableColors.entries) {
          expect(
            _contrast(readable.value, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key.name}: ${readable.key} on ${surface.key}',
          );
        }
        expect(
          _contrast(theme.line, surface.value),
          greaterThanOrEqualTo(1.5),
          reason: '${entry.key.name}: line on ${surface.key}',
        );
      }
      for (final surface in ['canvas', 'panel']) {
        expect(
          _contrast(theme.accent, surfaces[surface]!),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key.name}: accent on $surface',
        );
      }
      expect(_contrast(theme.panel, theme.canvas), greaterThanOrEqualTo(1.08));
      expect(_contrast(theme.raised, theme.panel), greaterThanOrEqualTo(1.08));
    }
  });

  test('Onyx has a neutral monochrome identity instead of copying Abyss', () {
    final accent = SharkTuneThemes.onyx.accent;
    final channels = [accent.r, accent.g, accent.b];
    final spread =
        channels.reduce((a, b) => a > b ? a : b) -
        channels.reduce((a, b) => a < b ? a : b);

    expect(spread, lessThanOrEqualTo(0.08));
    expect(SharkTuneThemes.onyx.accent, isNot(SharkTuneThemes.abyss.accent));
  });

  test('instrument text roles use the approved optical scale', () {
    final text = buildInstrumentTheme().extension<InstrumentTypeTheme>();

    expect(text, isNotNull);
    expect(text!.centsHero.fontSize, 96);
    expect(text.centsHero.height, 1);
    expect(text.centsHero.fontFamily, 'JetBrains Mono');
    expect(text.noteHero.fontSize, 52);
    expect(text.noteHero.fontFamily, 'IBM Plex Mono');
    expect(text.measurement.fontFamily, 'JetBrains Mono');
    expect(
      text.measurement.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
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
    expect(InstrumentMetrics.radius8, 8);
    expect(InstrumentMetrics.radius16, 16);
    expect(InstrumentMetrics.strokeHairline, 1);
    expect(InstrumentMetrics.strokeEmphasis, 2);
    expect(InstrumentMotion.immediate, Duration.zero);
    expect(InstrumentMotion.instrument, const Duration(milliseconds: 140));
    expect(InstrumentMotion.lockFlash, const Duration(milliseconds: 350));
  });

  test(
    'general controls use calm tactile surfaces without changing tuner geometry',
    () {
      for (final id in SharkTuneThemeId.values) {
        final theme = buildInstrumentTheme(id);
        final terminal = theme.extension<TerminalTheme>()!;
        final filledShape = theme.filledButtonTheme.style!.shape!.resolve({});
        final outlinedShape = theme.outlinedButtonTheme.style!.shape!.resolve(
          {},
        );
        final textShape = theme.textButtonTheme.style!.shape!.resolve({});
        final chipShape = theme.chipTheme.shape;

        expect(
          (filledShape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(8)),
          reason: '${id.name}: filled button',
        );
        expect(
          (outlinedShape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(8)),
          reason: '${id.name}: outlined button',
        );
        expect(
          (textShape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(8)),
          reason: '${id.name}: text button',
        );
        expect(
          (chipShape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(8)),
          reason: '${id.name}: chip',
        );
        expect(
          theme.outlinedButtonTheme.style!.backgroundColor!.resolve({}),
          terminal.panel,
          reason: '${id.name}: outlined surface',
        );
        expect(
          theme.filledButtonTheme.style!.side!.resolve({})!.color,
          terminal.accentEdge,
          reason: '${id.name}: filled edge',
        );
      }
    },
  );
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
