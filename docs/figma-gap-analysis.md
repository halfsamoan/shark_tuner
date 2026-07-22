# toauner Figma gap analysis

Date: 2026-07-14  
Figma file: `COwsi0untcn8JZi9Bggpou`  
Scope: Phase 7 foundations, shared components, and the song search → detail → tuner vertical slice

## Sources of truth

1. Product behavior and state names: Flutter code and tests.
2. Visual language and accessibility rules: `docs/design-playbook.md`.
3. UX priority and copy: `docs/ui-plan.md`.
4. Existing Figma nodes: retained for comparison until the replacement components are verified.

When sources disagree, product behavior remains fixed and the playbook replaces the older visual values.

## Phase 0 inventory

### Code

- Flutter exposes `TerminalTheme`, `InstrumentTypeTheme`, `InstrumentMetrics`, and `InstrumentMotion` as the code-side token contract.
- The six playbook text roles are defined, tested, and used across every production screen; literal sizes are confined to the role definitions.
- D2Coding and Pretendard are bundled in the Flutter app. Figma still needs those fonts available in its editing environment before final text styles are created.
- Shared Flutter widgets cover header, status bar, section label, definition row, verification badge, note cell, and pitch tape.
- Note and meter behavior exists, but the public widgets do not yet expose the playbook's complete named state sets.
- No `.figma.ts`, `.figma.js`, or Code Connect mapping exists.

### Figma file

- Pages: `Page 1`, `00 Components`, `01 Product Flow`.
- Four local variable collections and 49 variables were created in the prior Phase 1 run; their returned IDs are recorded in `reports/design/figma-state-toauner-v1.json`.
- Existing components:
  - `Button/Primary`
  - `Button/Tool`
  - `Field/Search`
  - `Status/Review`
  - `Status/Verified`
  - `SongRow/Default`
  - `NoteCell/Idle`
  - `NoteCell/Active`
  - `Chrome/HeaderBar`
  - `Chrome/StatusBar`
- Existing components use raw values and Inter rather than bound toauner tokens.
- D2Coding, Pretendard, and NeoDunggeunmo Code are not available to the Figma plugin environment.
- Material 3 and Simple Design System libraries are subscribed, but the design-system search returned no compatible toauner-specific asset.

## Keep, replace, and add

| Area | Existing state | Decision | Reason |
| --- | --- | --- | --- |
| Product flow | Flutter flow is implemented | Keep | Figma must document real behavior, not invent a parallel flow. |
| Existing Figma components | Flat, unbound, partial states | Keep temporarily, then archive | Useful as provenance; not production-ready without variables and variants. |
| Material components | Libraries subscribed | Use only for platform behavior reference | Default shape and card language conflicts with the instrument UI. |
| Color | Older seven-color palette | Replace | The playbook's semantic palette separates brand, lock, warning, information, text, and decorative grid roles. |
| Typography | Inter/system fallback and scattered sizes | Replace | Six named roles are required; Korean body and numeric instrument data use different families. |
| Elevation | Mostly one dark field | Replace | Five stepped surfaces communicate hierarchy without shadows. |
| Icons | Material rounded icons in Flutter | Reduce | Prefer terminal glyphs and text labels; retain platform icons only where they improve recognition or accessibility. |
| Note cell | Idle/active only in Figma | Rebuild as `NoteChip` variant set | Required states: idle, active auto/manual, hearing other, settling, locked, done. |
| Meter | Static pitch tape only in Flutter | Add `Meter` variant set | Required states: waiting, coarse, fine, locked with non-color direction encoding. |
| Guidance | Inline screen logic | Add `GuidanceSlot` variant set | Required states: pluck prompt, direction, wrong string, too quiet, noisy, settling. |
| Status | Two badges and one status bar | Add `StatusLine` variant set | Listening, warning, and developer content must be explicit and release-safe. |

## Token contract to create

- Primitive and semantic color variables using the exact names and values in `docs/design-playbook.md`.
- Spacing variables: 4, 8, 12, 16, 24, 32.
- Radius variables: 0, 2, 3, 4.
- Stroke variables: hairline 1 and emphasis 2.
- Motion variables: immediate 0 ms, instrument 120 ms, lock 180 ms; no spring or bounce.
- Text styles: Hero, Title, Subhead, Body, Caption, Status.
- Code syntax metadata should map semantic names to the future Flutter `TerminalTheme` extension.

## Conflicts and blockers

1. **Figma MCP limit:** the Starter-plan call limit still blocks metadata, library search, and post-create validation. Do not mutate the file until the 49 recorded variables can be read back and verified.
2. **Font availability:** the approved fonts are bundled in Flutter but were absent from the prior Figma plugin font inventory. Do not silently substitute a look-alike; install the fonts for Figma or explicitly approve a temporary fallback.
3. **Existing page naming:** old pages do not match the required `00 Foundations`, `01 Components`, `02 Screens`, `03 States & Flows` structure. Rename only after replacement assets exist so provenance is not lost.
4. **Generic library mismatch:** the last successful discovery found Material 3 and Simple Design System, but no toauner-compatible instrument component. Re-run library search after the MCP limit resets before creating each component.

## Build order

1. Create primitive variables, semantic aliases, spacing/radius/stroke/motion variables, and text styles.
2. Build and verify `NoteChip`, `Meter`, `GuidanceSlot`, and `StatusLine` variant sets.
3. Migrate reusable button, field, song row, header, and status components to variables.
4. Assemble search, song detail, live tuner, and 1.3x text-scale frames from instances.
5. Add state-flow frames and compare them with `reports/device/` screenshots.
6. Compare the token-bound Figma instances with Flutter device screenshots and adjust role-level tokens or layout constraints instead of introducing screen-local text sizes.

## Phase 0 exit decision

The component hierarchy and product behavior are fixed. Visual conflicts have deterministic resolutions from the playbook. Figma mutations remain paused until MCP readback is available; after that, the only expected user decision is the Figma font path.

## Phase 1 progress

- Created four token collections in Figma: Color Primitives, Color, Dimensions, and Motion.
- Created 49 variables: 17 hidden primitive colors, 17 semantic color aliases, 12 dimension tokens, and 3 motion durations.
- Semantic display names use Figma-safe slash hierarchy (`bg/sunken`); code and documentation retain the canonical dot token (`bg.sunken`).
- Every created variable has a stable `toauner_ds` key and run ID for idempotent continuation.
- The post-create validation call was blocked by the Figma Starter-plan MCP call limit. The returned IDs and pending validation are preserved in `reports/design/figma-state-toauner-v1.json`.
- Component and text-style creation remains paused. This avoids creating unverified aliases or silently substituting the missing approved fonts.
- A 2026-07-14 retry of page metadata, library discovery, and design-system search was blocked by the same Starter-plan MCP limit. No Figma state was changed.

## Flutter visual-language progress

- Replaced the flat `InstrumentColors.chrome` alias with explicit `sunken`, `panel`, `raised`, and `header` surfaces in the search, detail, tuner, header, status, and meter paths.
- Reserved lock greens for achieved/held tuning states and removed screen-local raw colors.
- Removed decorative action icons, the touch-irrelevant `Ctrl K` hint, generic empty-state iconography, and rounded completion icons. Navigation, search, and microphone permission remain the only approved icon-font affordances.
- Added a static compliance test that rejects retired neon colors, raw screen colors, gradients, drop shadows, the flat chrome alias, and unapproved icon-font usage.
- Migrated every production screen to the six optical type roles and added a regression test that rejects new literal font sizes outside the token module.
- Preserved the no-scroll primary tuner at normal scale while making 2.0x text, wrong-string guidance, and peg-direction correction states structurally usable.
- Full `tool/check.ps1` passed after the migration.
