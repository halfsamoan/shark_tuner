# toauner Design Contract

This is the durable visual contract for toauner. Read it before proposing,
reviewing, or implementing a Flutter UI change, alongside
`docs/design-playbook.md` and `docs/ui-plan.md`.

The contract is deliberately implementation-neutral: it defines visual
judgment, interaction, and evidence. The production source of colours,
elevation, and type roles remains `app/lib/src/app/instrument_theme.dart`.

## 1. Product and visual thesis

toauner is a high-precision Android/iOS guitar tuner for standard, drop, and
low-frequency guitar tuning. It is used while holding an instrument, often in
low light and a noisy room. It must feel like a calm audio instrument, not a
generic music app, a crypto dashboard, or a copied design-kit demo.

The product has three intentionally separate visual roles:

| Reference | What toauner takes | What it must not take |
| --- | --- | --- |
| GNOME / Adwaita | Calm page hierarchy, search/list/preference rows, empty states | Desktop chrome or its palette |
| Material 3 | 48dp targets, text-field, bottom-sheet, dialog, focus and accessibility behaviour | A default Google visual skin |
| toauner | Meter, Hz/cent data, string rail, alerts, diagnostics, tuning presets | Generic dashboard card language |

One screen has one unmistakable focal point. On the live tuner this is the
current tuning state. On the home screen it is starting a free tuning session.
On song flows it is applying that song's tuning.

## 2. Design lock and token ownership

- All visible colour, surface, shadow, border, and typography decisions use
  `TerminalTheme`, `InstrumentTypeTheme`, and `InstrumentMetrics` through
  `context.terminal` and `context.instrumentType`.
- Do not add display-facing hex values, a famous palette, or an ad-hoc theme in
  a screen. A new semantic need belongs in `TerminalTheme` first.
- The six supported themes are Abyss, Onyx, Amber, Violet, Paper, and Clipping.
  Paper is genuinely light; the other general themes are dark. Clipping is the
  sole deliberately damaged live-tuner skin and must remain legible.
- Theme meaning is semantic, not decorative: `success`, `warning`,
  `information`, and `danger` communicate measured state. Normal, idle, and
  selected navigation rows stay neutral unless their state needs attention.
- A theme change is a contract change: update this file, the playbook, tests,
  and physical-device evidence together.

## 3. Colour and surface discipline

The intended density is approximately 70–75% canvas/surface, 10–15% ink and
line, and at most 5–10% accent plus state colour. Accent is a decisive action
or an active measurement, never a decoration.

- Use one branded accent at a time within a local composition. The exception is
  the tuner state scale: lock, near, warning, and error are data meanings, not
  competing brand colours.
- Prefer surface separation, a hairline, or a small change in ink over another
  coloured card. `InstrumentSurface` is the sole generic elevation owner.
- Shadows are quiet, directional, and only on raised or sunken physical
  surfaces. No floating shadows on ordinary list rows.
- Paper requires the same semantic contrast as dark themes; it is not dark UI
  inverted to beige. Clipping may break frame rhythm, but never value contrast,
  touch targets, or reading order.

## 4. Typography and measurement hierarchy

Use a restrained two-family system.

| Role | Typeface and treatment |
| --- | --- |
| Product labels, titles, instructions | Pretendard/system sans, calm and compact |
| Hz, cent, confidence, RMS, diagnostics | JetBrains Mono or the configured mono role, tabular figures |
| Primary measured value | Visually about twice its unit/caption; unit must never compete with the value |
| Screen title | Clear page context, not marketing copy |
| Supporting copy | One short fact or next action; remove filler and duplicate labels |

Numbers must not shift width while updating. Values deserve the strongest
contrast on a tuner; frequency and target are supporting facts. Do not add a
third decorative font or use all-caps as a substitute for hierarchy.

## 5. Geometry, rhythm, and depth

- Work on a 4/8dp rhythm. The gap around a group is larger than the gap inside
  it. Use proximity to reveal information structure.
- Major surfaces use 12–16dp radius; ordinary controls use 8–12dp; instrument
  marks may use 2–4dp. Nested corners must visually agree with their parent.
- Every interactive target is at least 48dp in both dimensions, including text
  buttons, icon-only controls, chips, and bottom-sheet rows.
- Prefer one strong surface and quieter grouped rows over a stack of identical
  cards. Do not use bento/dashboard grids for a tuning task.
- Build first for the smallest supported Android width, then validate the
  physical 1080×2340 Samsung profile and iOS-safe layouts. Validate at 1.3× and
  2.0× text scale without clipping essential tuning information.

## 6. Component language

Generic product components:

- `InstrumentSurface`: the only generic material/elevation owner.
- `InstrumentActionRow`: calm Adwaita-like list/preference action with a text
  affordance when navigation needs explanation.
- `ThemeTile`, `SettingRow`, `SearchField`, `Loading/Empty/Error`, and bottom
  sheets must expose their selected, pressed, disabled, focused, and error
  states.

toauner product assets:

- `TunerNeedle`, `FrequencyReadout`, `CentMeter`, `StringRail`,
  `TuningLockState`, `ConfidenceBadge`, `ClippingWarningBanner`,
  `LowTuningModeBadge`, `StabilityRing`, `TerminalDiagnosticCard`,
  `SongTuningCard`, `GaugeRecommendationCard`, `PegDirectionGuide`, and
  `TuningPresetBottomSheet`.

These assets use a technical instrument vocabulary: sparse line work, stable
numerals, meaningful colour, and no ornament without a measurement or action.
Do not import a kit component unchanged and do not recreate web/React/shadcn
patterns in Flutter.

## 7. Flow and content rules

### Home and song search

Free tuning is the primary task. Song search is a deliberate secondary path.
The home may offer a compact preset rail, but it must not bury the first tuning
action beneath a song catalogue. Search and results use calm rows, 250ms
debounce, clear input, recent searches, loading, empty, and recoverable error
states.

### Song detail

Show title, artist, tuning, capo, and string arrangement before secondary
tools. There is one fixed, explicit tuning CTA. Metronome and tension are
supporting rows; never visual competitors with the tuning action.

### Live tuner

The understanding order is: current cent error → detected note/string → target
frequency → meter and direction → string rail → confidence/status → warning.
The user must understand the state in one second. Debug diagnostics are hidden
behind a development-only, collapsible boundary. First entry explains only
microphone use, device-local processing, and how to pluck a string.

### Tools and settings

Use labelled, text-forward bottom-sheet rows for discoverability. Settings are
small grouped preferences, not a diagnostics dump: theme, tolerance, haptics,
and motion are first-class; advanced technical details are not.

## 8. State, accessibility, and motion

Every data-bearing surface defines normal, loading, empty, error, disabled,
focused, selected, warning, and success/locked state as applicable. Empty and
error states provide one useful next action and never blame the player.

- TalkBack text expresses the tuning meaning, not just colour or geometry.
- Colour is never the only signal for clipping, tune direction, or lock.
- Respect both in-app reduced motion and platform reduced-motion settings.
- Motion is short, causal, and limited to a change in measurement or control
state. No decorative loops, delayed content, elastic bounces, or scroll-linked
effects.

## 9. Anti-AI-look rules

Reject these patterns unless the product requirement explicitly overrides them:

- Purple/blue gradient branding, gradient text, glassmorphism, backdrop blur,
  glowing neon panels, decorative blobs, or random texture.
- A central marketing hero, three matching feature cards, rainbow row colours,
  generic icon-in-a-pale-chip repetition, emoji UI icons, or a crypto-style
  dashboard.
- Mixed corner personalities, icon sets, shadow directions, control heights,
  or arbitrary spacing values.
- A copied community-kit palette, typography, component shape, or marketing
  layout. References are used for structure and interaction only.
- Placeholder, robotic, or over-explanatory copy. Prefer a short observable
  fact and a named next action.

## 10. Design quality gate

Before presenting a non-trivial UI change, review the affected screen against
this 100-point gate. A score of 80 is the minimum ship bar; critical failures
(direct colour, missing 48dp target, inaccessible contrast, or colour-only
state) block release regardless of score.

| Category | Points | Review question |
| --- | ---: | --- |
| Coherence | 20 | Do radius, control height, icon, surface, and accent choices agree? |
| Colour discipline | 16 | Are semantic tokens used, normal state neutral, and contrast sufficient? |
| Hierarchy and type | 16 | Is there one focal point and are measurement/value roles immediately clear? |
| Layout and rhythm | 12 | Does spacing communicate grouping without repetitive cards? |
| States and accessibility | 12 | Are state paths, labels, targets, scaling, and reduced motion covered? |
| UX writing | 12 | Does every action name its result and does copy remove filler? |
| Motion and craft | 12 | Is feedback causal, quiet, and free of ornamental effects? |

Report the score with evidence and fix the highest-gain issues first. The score
is a guardrail, not a reason to chase 100 while delaying a useful feature.

## 11. Implementation and evidence

1. Inspect the existing screen and reusable components before creating widgets.
2. State the user task, focal information, secondary information, and what is
   removed or demoted.
3. Add or adjust focused tests before implementation; keep the per-file
   compliance allowlist shrinking so every commit remains green.
4. Run formatter, relevant widget tests, colour/compliance checks, and
   `tool/check.ps1` for integrated UI work.
5. Inspect goldens only for stable layouts. Use contrast tests plus Samsung
   physical-device captures for theme validation.
6. Do not claim a visual result without viewing the target screen. Record real
   device evidence in `reports/design/`; that directory is evidence, not a
   source of design truth.

## 12. Reference translation

This contract borrows only method from StyleSeed, Superdesign, and the
awesome-design-md collection: persistent design context, evidence-led review,
clear token roles, state coverage, and an anti-generic quality gate. It does
not import their themes, components, CSS, HTML, React/shadcn code, or visual
identity.
