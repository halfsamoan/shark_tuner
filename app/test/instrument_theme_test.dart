import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';

void main() {
  test('terminal theme exposes the approved semantic color contract', () {
    final theme = buildInstrumentTheme();
    final terminal = theme.extension<TerminalTheme>();

    expect(terminal, isNotNull);
    expect(terminal!.backgroundSunken, const Color(0xFF070A08));
    expect(terminal.backgroundCanvas, const Color(0xFF0B0F0A));
    expect(terminal.backgroundPanel, const Color(0xFF131A15));
    expect(terminal.backgroundRaised, const Color(0xFF1C241E));
    expect(terminal.backgroundHeader, const Color(0xFF232D26));
    expect(terminal.lineHairline, const Color(0xFF2A342C));
    expect(terminal.brandPhosphor, const Color(0xFFA9E34B));
    expect(terminal.phosphorEdge, const Color(0xFFB8F34A));
    expect(terminal.lockFlood, const Color(0xFF46D67F));
    expect(terminal.lockHold, const Color(0xFF5FD98A));
    expect(terminal.warningAmber, const Color(0xFFF2A93B));
    expect(terminal.warningStroke, const Color(0xFFFFB000));
    expect(terminal.informationTeal, const Color(0xFF4FB0A6));
    expect(terminal.ink, const Color(0xFFE6EFE8));
    expect(terminal.inkSecondary, const Color(0xFFBCC9C0));
    expect(terminal.textSecondary, const Color(0xFF8CA093));
    expect(terminal.gridTick, const Color(0xFF46554C));
  });

  test('instrument text roles use only the six approved optical sizes', () {
    final theme = buildInstrumentTheme();
    final text = theme.extension<InstrumentTypeTheme>();

    expect(text, isNotNull);
    expect(text!.centsHero.fontSize, 96);
    expect(text.centsHero.height, 1);
    expect(text.centsHero.letterSpacing, -1.92);
    expect(text.centsHero.fontFamily, 'D2Coding');
    expect(text.title.fontSize, 32);
    expect(text.title.height, 1.1);
    expect(text.subhead.fontSize, 20);
    expect(text.subhead.height, 1.3);
    expect(text.body.fontSize, 16);
    expect(text.body.height, 1.5);
    expect(text.caption.fontSize, 13);
    expect(text.caption.height, 1.45);
    expect(text.status.fontSize, 11);
    expect(text.status.height, 1.2);
    expect(text.status.letterSpacing, .44);
    expect(text.status.fontFamily, 'D2Coding');
    expect(text.title.fontFamily, 'Pretendard');
    expect(text.body.fontFamily, 'Pretendard');
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
    expect(InstrumentMotion.instrument, const Duration(milliseconds: 120));
    expect(InstrumentMotion.lockFlash, const Duration(milliseconds: 180));
  });
}
