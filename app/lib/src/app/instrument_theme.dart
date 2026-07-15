import 'package:flutter/material.dart';

enum SharkTuneThemeId { abyss, onyx, amber, violet, paper, clipping }

extension SharkTuneThemeIdPresentation on SharkTuneThemeId {
  String get label => switch (this) {
    SharkTuneThemeId.abyss => 'Abyss',
    SharkTuneThemeId.onyx => 'Onyx',
    SharkTuneThemeId.amber => 'Amber',
    SharkTuneThemeId.violet => 'Violet',
    SharkTuneThemeId.paper => 'Paper',
    SharkTuneThemeId.clipping => 'Clipping',
  };

  String get description => switch (this) {
    SharkTuneThemeId.abyss => '깊은 아쿠아 계기판',
    SharkTuneThemeId.onyx => '순흑 무대 모드',
    SharkTuneThemeId.amber => '따뜻한 클래식',
    SharkTuneThemeId.violet => '보라색 야간 모드',
    SharkTuneThemeId.paper => '밝은 종이 계기판',
    SharkTuneThemeId.clipping => '실험적인 글리치 스킨',
  };

  bool get isExperimental => this == SharkTuneThemeId.clipping;
}

@immutable
class SharkTuneThemeSelection extends ThemeExtension<SharkTuneThemeSelection> {
  const SharkTuneThemeSelection(this.id);

  final SharkTuneThemeId id;

  @override
  SharkTuneThemeSelection copyWith({SharkTuneThemeId? id}) =>
      SharkTuneThemeSelection(id ?? this.id);

  @override
  SharkTuneThemeSelection lerp(
    covariant SharkTuneThemeSelection? other,
    double t,
  ) => t < 0.5 || other == null ? this : other;
}

@immutable
class TerminalTheme extends ThemeExtension<TerminalTheme> {
  const TerminalTheme({
    required this.brightness,
    required this.backgroundSunken,
    required this.backgroundCanvas,
    required this.backgroundPanel,
    required this.backgroundRaised,
    required this.backgroundHeader,
    required this.lineHairline,
    required this.accent,
    required this.accentEdge,
    required this.onAccent,
    required this.successFlood,
    required this.successHold,
    required this.warning,
    required this.warningStroke,
    required this.information,
    required this.danger,
    required this.onDanger,
    required this.ink,
    required this.inkSecondary,
    required this.textSecondary,
    required this.gridTick,
    required this.surfaceHighlight,
    required this.surfaceGroundLine,
  });

  final Brightness brightness;
  final Color backgroundSunken;
  final Color backgroundCanvas;
  final Color backgroundPanel;
  final Color backgroundRaised;
  final Color backgroundHeader;
  final Color lineHairline;
  final Color accent;
  final Color accentEdge;
  final Color onAccent;
  final Color successFlood;
  final Color successHold;
  final Color warning;
  final Color warningStroke;
  final Color information;
  final Color danger;
  final Color onDanger;
  final Color ink;
  final Color inkSecondary;
  final Color textSecondary;
  final Color gridTick;
  final Color surfaceHighlight;
  final Color surfaceGroundLine;

  // Short semantic aliases keep call sites readable without reintroducing a
  // global static palette. Every value still resolves from the active theme.
  Color get sunken => backgroundSunken;
  Color get canvas => backgroundCanvas;
  Color get panel => backgroundPanel;
  Color get raised => backgroundRaised;
  Color get header => backgroundHeader;
  Color get line => lineHairline;
  Color get phosphorEdge => accentEdge;
  Color get lockFlood => successFlood;
  Color get lockHold => successHold;
  Color get amber => warning;
  Color get text => ink;
  Color get muted => textSecondary;
  Color get accentInk => onAccent;

  @override
  TerminalTheme copyWith({
    Brightness? brightness,
    Color? backgroundSunken,
    Color? backgroundCanvas,
    Color? backgroundPanel,
    Color? backgroundRaised,
    Color? backgroundHeader,
    Color? lineHairline,
    Color? accent,
    Color? accentEdge,
    Color? onAccent,
    Color? successFlood,
    Color? successHold,
    Color? warning,
    Color? warningStroke,
    Color? information,
    Color? danger,
    Color? onDanger,
    Color? ink,
    Color? inkSecondary,
    Color? textSecondary,
    Color? gridTick,
    Color? surfaceHighlight,
    Color? surfaceGroundLine,
  }) {
    return TerminalTheme(
      brightness: brightness ?? this.brightness,
      backgroundSunken: backgroundSunken ?? this.backgroundSunken,
      backgroundCanvas: backgroundCanvas ?? this.backgroundCanvas,
      backgroundPanel: backgroundPanel ?? this.backgroundPanel,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      backgroundHeader: backgroundHeader ?? this.backgroundHeader,
      lineHairline: lineHairline ?? this.lineHairline,
      accent: accent ?? this.accent,
      accentEdge: accentEdge ?? this.accentEdge,
      onAccent: onAccent ?? this.onAccent,
      successFlood: successFlood ?? this.successFlood,
      successHold: successHold ?? this.successHold,
      warning: warning ?? this.warning,
      warningStroke: warningStroke ?? this.warningStroke,
      information: information ?? this.information,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      textSecondary: textSecondary ?? this.textSecondary,
      gridTick: gridTick ?? this.gridTick,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      surfaceGroundLine: surfaceGroundLine ?? this.surfaceGroundLine,
    );
  }

  @override
  TerminalTheme lerp(covariant TerminalTheme? other, double t) {
    if (other == null) return this;
    return TerminalTheme(
      brightness: t < .5 ? brightness : other.brightness,
      backgroundSunken: Color.lerp(
        backgroundSunken,
        other.backgroundSunken,
        t,
      )!,
      backgroundCanvas: Color.lerp(
        backgroundCanvas,
        other.backgroundCanvas,
        t,
      )!,
      backgroundPanel: Color.lerp(backgroundPanel, other.backgroundPanel, t)!,
      backgroundRaised: Color.lerp(
        backgroundRaised,
        other.backgroundRaised,
        t,
      )!,
      backgroundHeader: Color.lerp(
        backgroundHeader,
        other.backgroundHeader,
        t,
      )!,
      lineHairline: Color.lerp(lineHairline, other.lineHairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentEdge: Color.lerp(accentEdge, other.accentEdge, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      successFlood: Color.lerp(successFlood, other.successFlood, t)!,
      successHold: Color.lerp(successHold, other.successHold, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningStroke: Color.lerp(warningStroke, other.warningStroke, t)!,
      information: Color.lerp(information, other.information, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      gridTick: Color.lerp(gridTick, other.gridTick, t)!,
      surfaceHighlight: Color.lerp(
        surfaceHighlight,
        other.surfaceHighlight,
        t,
      )!,
      surfaceGroundLine: Color.lerp(
        surfaceGroundLine,
        other.surfaceGroundLine,
        t,
      )!,
    );
  }
}

@immutable
class InstrumentTypeTheme extends ThemeExtension<InstrumentTypeTheme> {
  const InstrumentTypeTheme({
    required this.centsHero,
    required this.noteHero,
    required this.measurement,
    required this.title,
    required this.subhead,
    required this.body,
    required this.caption,
    required this.status,
  });

  factory InstrumentTypeTheme.forTerminal(TerminalTheme terminal) {
    return InstrumentTypeTheme(
      centsHero: TextStyle(
        color: terminal.ink,
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const ['IBM Plex Sans KR'],
        fontSize: 96,
        height: 1,
        letterSpacing: -1.5,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      noteHero: TextStyle(
        color: terminal.ink,
        fontFamily: 'IBM Plex Mono',
        fontFamilyFallback: const ['IBM Plex Sans KR'],
        fontSize: 52,
        height: 56 / 52,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      measurement: TextStyle(
        color: terminal.ink,
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const ['IBM Plex Sans KR'],
        fontSize: 13,
        height: 19 / 13,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        color: terminal.ink,
        fontFamily: 'IBM Plex Sans KR',
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
      ),
      subhead: TextStyle(
        color: terminal.ink,
        fontFamily: 'IBM Plex Sans KR',
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      body: TextStyle(
        color: terminal.ink,
        fontFamily: 'IBM Plex Sans KR',
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      caption: TextStyle(
        color: terminal.textSecondary,
        fontFamily: 'IBM Plex Sans KR',
        fontSize: 13,
        height: 19 / 13,
        fontWeight: FontWeight.w400,
      ),
      status: TextStyle(
        color: terminal.textSecondary,
        fontFamily: 'IBM Plex Mono',
        fontFamilyFallback: const ['IBM Plex Sans KR'],
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: .33,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  final TextStyle centsHero;
  final TextStyle noteHero;
  final TextStyle measurement;
  final TextStyle title;
  final TextStyle subhead;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle status;

  @override
  InstrumentTypeTheme copyWith({
    TextStyle? centsHero,
    TextStyle? noteHero,
    TextStyle? measurement,
    TextStyle? title,
    TextStyle? subhead,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? status,
  }) {
    return InstrumentTypeTheme(
      centsHero: centsHero ?? this.centsHero,
      noteHero: noteHero ?? this.noteHero,
      measurement: measurement ?? this.measurement,
      title: title ?? this.title,
      subhead: subhead ?? this.subhead,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      status: status ?? this.status,
    );
  }

  @override
  InstrumentTypeTheme lerp(covariant InstrumentTypeTheme? other, double t) {
    if (other == null) return this;
    return InstrumentTypeTheme(
      centsHero: TextStyle.lerp(centsHero, other.centsHero, t)!,
      noteHero: TextStyle.lerp(noteHero, other.noteHero, t)!,
      measurement: TextStyle.lerp(measurement, other.measurement, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      subhead: TextStyle.lerp(subhead, other.subhead, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      status: TextStyle.lerp(status, other.status, t)!,
    );
  }
}

abstract final class InstrumentMetrics {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double radius0 = 0;
  static const double radius2 = 2;
  static const double radius3 = 3;
  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius16 = 16;
  static const double strokeHairline = 1;
  static const double strokeEmphasis = 2;
}

abstract final class InstrumentMotion {
  static const immediate = Duration.zero;
  static const instrument = Duration(milliseconds: 140);
  static const lockFlash = Duration(milliseconds: 350);
}

abstract final class SharkTuneThemes {
  static const abyss = TerminalTheme(
    brightness: Brightness.dark,
    backgroundSunken: Color(0xFF050B0C),
    backgroundCanvas: Color(0xFF0B1214),
    backgroundPanel: Color(0xFF142326),
    backgroundRaised: Color(0xFF1A2E31),
    backgroundHeader: Color(0xFF102023),
    lineHairline: Color(0xFF78908D),
    accent: Color(0xFF42D3C8),
    accentEdge: Color(0xFF8FE9E1),
    onAccent: Color(0xFF061C1A),
    successFlood: Color(0xFF4FD99A),
    successHold: Color(0xFF63D39C),
    warning: Color(0xFFF2A93B),
    warningStroke: Color(0xFFFFB000),
    information: Color(0xFF5AA8E0),
    danger: Color(0xFFFF5C72),
    onDanger: Color(0xFF210208),
    ink: Color(0xFFF4FBF9),
    inkSecondary: Color(0xFFD2E5E1),
    textSecondary: Color(0xFFB1CBC5),
    gridTick: Color(0xFF789892),
    surfaceHighlight: Color(0x0DE7F2EF),
    surfaceGroundLine: Color(0x73000000),
  );

  static const onyx = TerminalTheme(
    brightness: Brightness.dark,
    backgroundSunken: Color(0xFF050505),
    backgroundCanvas: Color(0xFF0A0A0A),
    backgroundPanel: Color(0xFF151515),
    backgroundRaised: Color(0xFF202020),
    backgroundHeader: Color(0xFF111111),
    lineHairline: Color(0xFF777777),
    accent: Color(0xFFECECEC),
    accentEdge: Color(0xFFFFFFFF),
    onAccent: Color(0xFF050505),
    successFlood: Color(0xFF4FB98C),
    successHold: Color(0xFF5FB394),
    warning: Color(0xFFD69A45),
    warningStroke: Color(0xFFE0A84E),
    information: Color(0xFF68B7E8),
    danger: Color(0xFFE06172),
    onDanger: Color(0xFF1D0207),
    ink: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFDADADA),
    textSecondary: Color(0xFFBDBDBD),
    gridTick: Color(0xFF8A8A8A),
    surfaceHighlight: Color(0x0DD4E3DF),
    surfaceGroundLine: Color(0x80000000),
  );

  static const amber = TerminalTheme(
    brightness: Brightness.dark,
    backgroundSunken: Color(0xFF100D09),
    backgroundCanvas: Color(0xFF1A1610),
    backgroundPanel: Color(0xFF2B2419),
    backgroundRaised: Color(0xFF3A3021),
    backgroundHeader: Color(0xFF2A2318),
    lineHairline: Color(0xFF8C775A),
    accent: Color(0xFFE9B65B),
    accentEdge: Color(0xFFF5CE88),
    onAccent: Color(0xFF211908),
    successFlood: Color(0xFFB8BB26),
    successHold: Color(0xFFA9B665),
    warning: Color(0xFFFE8019),
    warningStroke: Color(0xFFFB4934),
    information: Color(0xFF83A598),
    danger: Color(0xFFFF6B5C),
    onDanger: Color(0xFF260300),
    ink: Color(0xFFFFF4D5),
    inkSecondary: Color(0xFFEAD7B1),
    textSecondary: Color(0xFFD6C29D),
    gridTick: Color(0xFF9B7B52),
    surfaceHighlight: Color(0x14EBDBB2),
    surfaceGroundLine: Color(0x73000000),
  );

  static const violet = TerminalTheme(
    brightness: Brightness.dark,
    backgroundSunken: Color(0xFF100E14),
    backgroundCanvas: Color(0xFF15131B),
    backgroundPanel: Color(0xFF262232),
    backgroundRaised: Color(0xFF362F43),
    backgroundHeader: Color(0xFF211D2A),
    lineHairline: Color(0xFF877A9C),
    accent: Color(0xFFC9A9E8),
    accentEdge: Color(0xFFE1D1F2),
    onAccent: Color(0xFF21172A),
    successFlood: Color(0xFF50FA7B),
    successHold: Color(0xFF69D98A),
    warning: Color(0xFFFFB86C),
    warningStroke: Color(0xFFFF9C4A),
    information: Color(0xFF8BE9FD),
    danger: Color(0xFFFF5555),
    onDanger: Color(0xFF260000),
    ink: Color(0xFFFFF9FF),
    inkSecondary: Color(0xFFE4D8EE),
    textSecondary: Color(0xFFC7B9D2),
    gridTick: Color(0xFF927CAD),
    surfaceHighlight: Color(0x14F8F8F2),
    surfaceGroundLine: Color(0x73000000),
  );

  static const paper = TerminalTheme(
    brightness: Brightness.light,
    backgroundSunken: Color(0xFFD6C9AD),
    backgroundCanvas: Color(0xFFE9E1CF),
    backgroundPanel: Color(0xFFF7EEDB),
    backgroundRaised: Color(0xFFFFFDF7),
    backgroundHeader: Color(0xFFDCD2B9),
    lineHairline: Color(0xFF736B5A),
    accent: Color(0xFF165A7B),
    accentEdge: Color(0xFF174969),
    onAccent: Color(0xFFFFFFFF),
    successFlood: Color(0xFF6C8E00),
    successHold: Color(0xFF5E7C00),
    warning: Color(0xFFC1600F),
    warningStroke: Color(0xFFB5410F),
    information: Color(0xFF167F78),
    danger: Color(0xFFB3212D),
    onDanger: Color(0xFFFFFFFF),
    ink: Color(0xFF102F38),
    inkSecondary: Color(0xFF294750),
    textSecondary: Color(0xFF3D5358),
    gridTick: Color(0xFF645E50),
    surfaceHighlight: Color(0xB3FFFFFF),
    surfaceGroundLine: Color(0x33586E75),
  );

  static const clipping = TerminalTheme(
    brightness: Brightness.dark,
    backgroundSunken: Color(0xFF12070D),
    backgroundCanvas: Color(0xFFF3DCE8),
    backgroundPanel: Color(0xFFFFF9FC),
    backgroundRaised: Color(0xFFE8C7D8),
    backgroundHeader: Color(0xFFFFD9E9),
    lineHairline: Color(0xFF0B0508),
    accent: Color(0xFFAA004E),
    accentEdge: Color(0xFF006C76),
    onAccent: Color(0xFFFFFFFF),
    successFlood: Color(0xFFE8FF3A),
    successHold: Color(0xFF526000),
    warning: Color(0xFF5D4800),
    warningStroke: Color(0xFF493800),
    information: Color(0xFF005F68),
    danger: Color(0xFF9E0049),
    onDanger: Color(0xFFFFFFFF),
    ink: Color(0xFF090306),
    inkSecondary: Color(0xFF33242B),
    textSecondary: Color(0xFF514047),
    gridTick: Color(0xFF66515B),
    surfaceHighlight: Color(0xFFFFFFFF),
    surfaceGroundLine: Color(0x520B0709),
  );

  static const values = <SharkTuneThemeId, TerminalTheme>{
    SharkTuneThemeId.abyss: abyss,
    SharkTuneThemeId.onyx: onyx,
    SharkTuneThemeId.amber: amber,
    SharkTuneThemeId.violet: violet,
    SharkTuneThemeId.paper: paper,
    SharkTuneThemeId.clipping: clipping,
  };

  static TerminalTheme resolve(SharkTuneThemeId id) => values[id]!;
}

extension InstrumentThemeContext on BuildContext {
  TerminalTheme get terminal {
    final value = Theme.of(this).extension<TerminalTheme>();
    assert(value != null, 'TerminalTheme must be registered on ThemeData.');
    return value!;
  }

  InstrumentTypeTheme get instrumentType {
    final value = Theme.of(this).extension<InstrumentTypeTheme>();
    assert(
      value != null,
      'InstrumentTypeTheme must be registered on ThemeData.',
    );
    return value!;
  }

  SharkTuneThemeId get sharkTuneThemeId {
    final value = Theme.of(this).extension<SharkTuneThemeSelection>();
    assert(value != null, 'SharkTuneThemeSelection must be registered.');
    return value!.id;
  }
}

ThemeData buildInstrumentTheme([
  SharkTuneThemeId themeId = SharkTuneThemeId.abyss,
]) {
  final terminal = SharkTuneThemes.resolve(themeId);
  final type = InstrumentTypeTheme.forTerminal(terminal);
  final scheme = ColorScheme(
    brightness: terminal.brightness,
    primary: terminal.accent,
    onPrimary: terminal.onAccent,
    secondary: terminal.information,
    onSecondary: terminal.backgroundSunken,
    error: terminal.danger,
    onError: terminal.onDanger,
    surface: terminal.backgroundCanvas,
    onSurface: terminal.ink,
  );
  final outline = OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(2)),
    borderSide: BorderSide(color: terminal.lineHairline),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: terminal.brightness,
    colorScheme: scheme,
    extensions: [terminal, type, SharkTuneThemeSelection(themeId)],
    fontFamily: 'IBM Plex Sans KR',
    scaffoldBackgroundColor: terminal.backgroundCanvas,
    dividerColor: terminal.lineHairline,
    splashFactory: NoSplash.splashFactory,
    textTheme: TextTheme(
      displayLarge: type.centsHero,
      displayMedium: type.noteHero,
      headlineMedium: type.title,
      titleMedium: type.subhead,
      bodyMedium: type.body,
      bodySmall: type.caption,
      labelSmall: type.status,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: terminal.raised,
      modalBackgroundColor: terminal.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(InstrumentMetrics.radius16),
        ),
      ),
      dragHandleColor: terminal.lineHairline,
      dragHandleSize: const Size(32, 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: terminal.backgroundPanel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: type.caption,
      prefixIconColor: terminal.textSecondary,
      suffixIconColor: terminal.textSecondary,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: terminal.accentEdge),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: terminal.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: terminal.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: terminal.onAccent,
        backgroundColor: terminal.accent,
        disabledForegroundColor: terminal.muted,
        disabledBackgroundColor: terminal.raised,
        side: BorderSide(color: terminal.accentEdge),
        overlayColor: terminal.onAccent.withValues(alpha: 0.12),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: type.body.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: terminal.accent,
        backgroundColor: terminal.panel,
        disabledForegroundColor: terminal.muted,
        disabledBackgroundColor: terminal.sunken,
        side: BorderSide(color: terminal.lineHairline),
        overlayColor: terminal.accent.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: type.body.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: terminal.accent,
        overlayColor: terminal.accent.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: type.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: terminal.backgroundPanel,
      disabledColor: terminal.backgroundSunken,
      selectedColor: terminal.accent,
      secondarySelectedColor: terminal.accent,
      labelStyle: type.caption.copyWith(color: terminal.ink),
      secondaryLabelStyle: type.caption.copyWith(color: terminal.onAccent),
      side: BorderSide(color: terminal.lineHairline),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );
}
