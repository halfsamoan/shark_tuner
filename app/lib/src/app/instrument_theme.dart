import 'package:flutter/material.dart';

@immutable
class TerminalTheme extends ThemeExtension<TerminalTheme> {
  const TerminalTheme({
    required this.backgroundSunken,
    required this.backgroundCanvas,
    required this.backgroundPanel,
    required this.backgroundRaised,
    required this.backgroundHeader,
    required this.lineHairline,
    required this.brandPhosphor,
    required this.phosphorEdge,
    required this.lockFlood,
    required this.lockHold,
    required this.warningAmber,
    required this.warningStroke,
    required this.informationTeal,
    required this.ink,
    required this.inkSecondary,
    required this.textSecondary,
    required this.gridTick,
  });

  static const dark = TerminalTheme(
    backgroundSunken: Color(0xFF070A08),
    backgroundCanvas: Color(0xFF0B0F0A),
    backgroundPanel: Color(0xFF131A15),
    backgroundRaised: Color(0xFF1C241E),
    backgroundHeader: Color(0xFF232D26),
    lineHairline: Color(0xFF2A342C),
    brandPhosphor: Color(0xFFA9E34B),
    phosphorEdge: Color(0xFFB8F34A),
    lockFlood: Color(0xFF46D67F),
    lockHold: Color(0xFF5FD98A),
    warningAmber: Color(0xFFF2A93B),
    warningStroke: Color(0xFFFFB000),
    informationTeal: Color(0xFF4FB0A6),
    ink: Color(0xFFE6EFE8),
    inkSecondary: Color(0xFFBCC9C0),
    textSecondary: Color(0xFF8CA093),
    gridTick: Color(0xFF46554C),
  );

  final Color backgroundSunken;
  final Color backgroundCanvas;
  final Color backgroundPanel;
  final Color backgroundRaised;
  final Color backgroundHeader;
  final Color lineHairline;
  final Color brandPhosphor;
  final Color phosphorEdge;
  final Color lockFlood;
  final Color lockHold;
  final Color warningAmber;
  final Color warningStroke;
  final Color informationTeal;
  final Color ink;
  final Color inkSecondary;
  final Color textSecondary;
  final Color gridTick;

  @override
  TerminalTheme copyWith({
    Color? backgroundSunken,
    Color? backgroundCanvas,
    Color? backgroundPanel,
    Color? backgroundRaised,
    Color? backgroundHeader,
    Color? lineHairline,
    Color? brandPhosphor,
    Color? phosphorEdge,
    Color? lockFlood,
    Color? lockHold,
    Color? warningAmber,
    Color? warningStroke,
    Color? informationTeal,
    Color? ink,
    Color? inkSecondary,
    Color? textSecondary,
    Color? gridTick,
  }) {
    return TerminalTheme(
      backgroundSunken: backgroundSunken ?? this.backgroundSunken,
      backgroundCanvas: backgroundCanvas ?? this.backgroundCanvas,
      backgroundPanel: backgroundPanel ?? this.backgroundPanel,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      backgroundHeader: backgroundHeader ?? this.backgroundHeader,
      lineHairline: lineHairline ?? this.lineHairline,
      brandPhosphor: brandPhosphor ?? this.brandPhosphor,
      phosphorEdge: phosphorEdge ?? this.phosphorEdge,
      lockFlood: lockFlood ?? this.lockFlood,
      lockHold: lockHold ?? this.lockHold,
      warningAmber: warningAmber ?? this.warningAmber,
      warningStroke: warningStroke ?? this.warningStroke,
      informationTeal: informationTeal ?? this.informationTeal,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      textSecondary: textSecondary ?? this.textSecondary,
      gridTick: gridTick ?? this.gridTick,
    );
  }

  @override
  TerminalTheme lerp(covariant TerminalTheme? other, double t) {
    if (other == null) return this;
    return TerminalTheme(
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
      brandPhosphor: Color.lerp(brandPhosphor, other.brandPhosphor, t)!,
      phosphorEdge: Color.lerp(phosphorEdge, other.phosphorEdge, t)!,
      lockFlood: Color.lerp(lockFlood, other.lockFlood, t)!,
      lockHold: Color.lerp(lockHold, other.lockHold, t)!,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t)!,
      warningStroke: Color.lerp(warningStroke, other.warningStroke, t)!,
      informationTeal: Color.lerp(informationTeal, other.informationTeal, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      gridTick: Color.lerp(gridTick, other.gridTick, t)!,
    );
  }
}

@immutable
class InstrumentTypeTheme extends ThemeExtension<InstrumentTypeTheme> {
  const InstrumentTypeTheme({
    required this.centsHero,
    required this.title,
    required this.subhead,
    required this.body,
    required this.caption,
    required this.status,
  });

  static const standard = InstrumentTypeTheme(
    centsHero: TextStyle(
      color: InstrumentColors.ink,
      fontFamily: 'D2Coding',
      fontSize: 96,
      height: 1,
      letterSpacing: -1.92,
      fontWeight: FontWeight.w400,
    ),
    title: TextStyle(
      color: InstrumentColors.ink,
      fontFamily: 'Pretendard',
      fontSize: 32,
      height: 1.1,
      fontWeight: FontWeight.w600,
    ),
    subhead: TextStyle(
      color: InstrumentColors.ink,
      fontFamily: 'Pretendard',
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(
      color: InstrumentColors.ink,
      fontFamily: 'Pretendard',
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    caption: TextStyle(
      color: InstrumentColors.textSecondary,
      fontFamily: 'Pretendard',
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    status: TextStyle(
      color: InstrumentColors.textSecondary,
      fontFamily: 'D2Coding',
      fontSize: 11,
      height: 1.2,
      letterSpacing: .44,
      fontWeight: FontWeight.w400,
    ),
  );

  final TextStyle centsHero;
  final TextStyle title;
  final TextStyle subhead;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle status;

  @override
  InstrumentTypeTheme copyWith({
    TextStyle? centsHero,
    TextStyle? title,
    TextStyle? subhead,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? status,
  }) {
    return InstrumentTypeTheme(
      centsHero: centsHero ?? this.centsHero,
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
  static const double strokeHairline = 1;
  static const double strokeEmphasis = 2;
}

abstract final class InstrumentMotion {
  static const immediate = Duration.zero;
  static const instrument = Duration(milliseconds: 120);
  static const lockFlash = Duration(milliseconds: 180);
}

abstract final class InstrumentColors {
  static const sunken = Color(0xFF070A08);
  static const canvas = Color(0xFF0B0F0A);
  static const panel = Color(0xFF131A15);
  static const raised = Color(0xFF1C241E);
  static const header = Color(0xFF232D26);
  static const line = Color(0xFF2A342C);
  static const accent = Color(0xFFA9E34B);
  static const phosphorEdge = Color(0xFFB8F34A);
  static const lockFlood = Color(0xFF46D67F);
  static const lockHold = Color(0xFF5FD98A);
  static const amber = Color(0xFFF2A93B);
  static const warningStroke = Color(0xFFFFB000);
  static const information = Color(0xFF4FB0A6);
  static const ink = Color(0xFFE6EFE8);
  static const inkSecondary = Color(0xFFBCC9C0);
  static const textSecondary = Color(0xFF8CA093);
  static const gridTick = Color(0xFF46554C);

  // Transitional aliases keep existing screens stable while each one migrates
  // to explicit semantic tokens.
  static const chrome = canvas;
  static const text = ink;
  static const muted = textSecondary;
  static const accentInk = Color(0xFF111508);
  static const danger = Color(0xFFF36A6A);
}

ThemeData buildInstrumentTheme() {
  const terminal = TerminalTheme.dark;
  const type = InstrumentTypeTheme.standard;
  const scheme = ColorScheme.dark(
    primary: InstrumentColors.accent,
    onPrimary: InstrumentColors.accentInk,
    surface: InstrumentColors.canvas,
    onSurface: InstrumentColors.ink,
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
    extensions: [terminal, type],
    scaffoldBackgroundColor: InstrumentColors.canvas,
    dividerColor: InstrumentColors.line,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displayLarge: type.centsHero,
      headlineMedium: type.title,
      titleMedium: type.subhead,
      bodyMedium: type.body,
      bodySmall: type.caption,
      labelSmall: type.status,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: InstrumentColors.panel,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: type.caption,
      prefixIconColor: InstrumentColors.textSecondary,
      suffixIconColor: InstrumentColors.textSecondary,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: InstrumentColors.phosphorEdge),
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
        textStyle: type.body.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
