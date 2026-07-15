---
name: toauner-design-review
description: Review or improve a toauner Flutter screen when it looks generic, AI-generated, visually inconsistent, or insufficiently usable for real guitar tuning. Use before presenting any substantial UI change and after implementing a new screen, component, theme, or interaction flow.
---

# toauner design review

Use this skill as a product-design quality gate, not as a source of widgets or
web styling. It applies to Flutter Android/iOS UI only.

## Required context

Read these before the review:

1. `DESIGN.md`
2. `docs/design-playbook.md`
3. `docs/ui-plan.md`
4. The affected Flutter widget, its reusable components, and its focused tests

For a Figma reference, extract layout intent, component role, spacing rhythm,
type hierarchy, and interaction model. Do not copy the reference palette,
component appearance, HTML, React, Tailwind, or shadcn code.

## Design judgment before implementation

Write four short findings before changing code:

1. **Player task:** what a guitarist is trying to accomplish now.
2. **Focal point:** the information that must be understood in one second.
3. **Hierarchy:** primary, secondary, and hidden/demoted information.
4. **Subtraction:** decoration, duplicate copy, or cards that can be removed.

For live tuning, the order is cent error, note/string, target Hz, meter and
direction, string rail, confidence/status, then warnings. For the home screen,
starting free tuning outranks song discovery. For settings and search, use calm
grouped rows and a text-forward hierarchy.

## Review rubric — 100 points

Start every category at full points and subtract only for evidence in code,
goldens, screenshots, or a physical device capture. Cite the file and line or
visual evidence for every deduction.

| Category | Points | Deduct for |
| --- | ---: | --- |
| Coherence | 20 | Mixed radius, control heights, icons, shadow language, or arbitrary visual personalities. |
| Colour discipline | 16 | Direct colours instead of semantic tokens, normal rows in state colours, decorative hues, weak contrast, or colour-only meaning. |
| Hierarchy and typography | 16 | No focal point, all-equal emphasis, unstable measurement numbers, or an unreadable value/unit relationship. |
| Layout and rhythm | 12 | Off-grid spacing, cramped small screens, repeated equal cards, or gaps that fail to show grouping. |
| States and accessibility | 12 | Missing loading/empty/error/disabled/focus/selected state, under-48dp target, poor TalkBack, no text scaling or reduced-motion consideration. |
| UX writing | 12 | Vague action labels, filler, robotic diagnostics, duplicate terms, or an error that blames the player. |
| Motion and craft | 12 | Decorative motion, blocking animation, blur/glass, gradient, glow, or unjustified shadows. |

The target is 80/100. A score does not excuse a blocking defect: hardcoded
screen colour, invalid contrast, colour-only warning, missing essential state,
or uninspected changed visual must be fixed before release.

## toauner-specific rules

- Use `context.terminal`, `context.instrumentType`, `InstrumentMetrics`, and
  `InstrumentSurface`; do not rebuild a parallel visual system in a screen.
- The generic one-accent rule has a narrow exception: success, near, warning,
  and danger are measurement severity and may appear together only where the
  tuner state requires them. Normal state remains neutral.
- JetBrains Mono is for Hz, cents, confidence, RMS, and diagnostic figures.
  Product labels use the configured sans role. Keep values tabular and stable.
- Touch targets are at least 48dp. Bottom sheets, fields, chips, and dialogs
  use Material 3 interaction behaviour while their appearance remains toauner.
- No gradients, gradient text, glassmorphism, backdrop blur, decorative neon,
  copied kit skins, icon-chip repetition, emoji UI icons, rainbow lists,
  generic SaaS heroes, bento grids, or crypto dashboard styling.
- Clipping is deliberately damaged only in its dedicated live-tuner skin. Its
  information order, text contrast, target size, and meter legibility remain
  non-negotiable.

## Review output

Use this format in the implementation report:

```text
## Design score: 84 / 100 — <screen>

Keep: <what already supports real tuning>
Change: <highest-gain improvements>
Reject: <generic or inaccessible pattern removed>

Coherence              17/20  <evidence>
Colour discipline      14/16  <evidence>
Hierarchy and type     15/16  <evidence>
Layout and rhythm      10/12  <evidence>
States and access.     10/12  <evidence>
UX writing             10/12  <evidence>
Motion and craft        8/12  <evidence>

Fix first:
1. <largest score or usability gain>
2. <next>
```

After applying the changes, re-review the affected screen, run focused tests,
and inspect a golden or real device capture. For integrated changes, run
`tool/check.ps1`; record device evidence under `reports/design/`.
