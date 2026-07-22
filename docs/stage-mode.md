# Stage mode

Stage mode is a focused readout for tuning while standing farther from the
phone. It is entered from the live tuner and reuses that tuner's existing
capture and DSP engine.

## Product contract

- No second microphone session or pitch detector is created. Automatic string
  switching, octave guards, stabilization, and in-tune locking remain the same
  product path as the normal tuner.
- The screen shows only the active note, integer cents, a direction glyph plus
  action text, the pitch tape, and a compact status line. Song cards, Hz,
  diagnostics, peg setup, and tension data are excluded.
- Direction and completion never rely on color alone: `▲ 올리세요`,
  `▼ 낮추세요`, `… 거의 맞았어요`, and `✓ 인튠` remain readable under stage
  lighting and in grayscale.
- The existing tuner route owns screen-awake behavior, so entering and leaving
  stage mode cannot accidentally release the wakelock while tuning continues.
- TalkBack announcements use the shared one-second throttled live region.
- The layout is non-scrolling and covered at 2.0x text scale.

## Remaining device verification

Track B must still verify one-meter readability, grayscale screenshots,
TalkBack traversal, 30-minute battery impact, and behavior when the display is
dimmed by Android power or thermal policy. Those checks cannot be inferred from
widget tests.
