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

- Flutter has one flat `InstrumentColors` palette and no `ThemeExtension`.
- Text sizes are distributed across screens instead of using the six playbook roles.
- The app does not bundle D2Coding or Pretendard yet, so device rendering currently uses platform fallback fonts.
- Shared Flutter widgets cover header, status bar, section label, definition row, verification badge, note cell, and pitch tape.
- Note and meter behavior exists, but the public widgets do not yet expose the playbook's complete named state sets.
- No `.figma.ts`, `.figma.js`, or Code Connect mapping exists.

### Figma file

- Pages: `Page 1`, `00 Components`, `01 Product Flow`.
- Local variables, paint styles, text styles, grid styles, and effect styles: none.
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

1. **Font availability:** the approved fonts are absent in both the Figma plugin environment and the Flutter bundle. Do not silently substitute a look-alike. Flutter can bundle the OFL releases; Figma requires local font installation or an explicit temporary fallback decision.
2. **Dirty playbook:** `docs/design-playbook.md` contains user-owned uncommitted changes. Treat it as authoritative input but do not stage it without confirmation.
3. **Existing page naming:** old pages do not match the required `00 Foundations`, `01 Components`, `02 Screens`, `03 States & Flows` structure. Rename only after replacement assets exist so provenance is not lost.
4. **Generic library mismatch:** subscribed Material/Simple assets are implementation references, not visual sources for the toauner component set.

## Build order

1. Create primitive variables, semantic aliases, spacing/radius/stroke/motion variables, and text styles.
2. Build and verify `NoteChip`, `Meter`, `GuidanceSlot`, and `StatusLine` variant sets.
3. Migrate reusable button, field, song row, header, and status components to variables.
4. Assemble search, song detail, live tuner, and 1.3x text-scale frames from instances.
5. Add state-flow frames and compare them with `reports/device/` screenshots.
6. Update Flutter theme tokens and shared widgets, then run widget tests and device screenshots.

## Phase 0 exit decision

The component hierarchy and product behavior are fixed. Visual conflicts have deterministic resolutions from the playbook. The only unresolved choice is the Figma font path; no Figma text style should be presented as final until the approved fonts are available or the user explicitly approves a temporary fallback.

## Phase 1 progress

- Created four token collections in Figma: Color Primitives, Color, Dimensions, and Motion.
- Created 49 variables: 17 hidden primitive colors, 17 semantic color aliases, 12 dimension tokens, and 3 motion durations.
- Semantic display names use Figma-safe slash hierarchy (`bg/sunken`); code and documentation retain the canonical dot token (`bg.sunken`).
- Every created variable has a stable `toauner_ds` key and run ID for idempotent continuation.
- The post-create validation call was blocked by the Figma Starter-plan MCP call limit. The returned IDs and pending validation are preserved in `reports/design/figma-state-toauner-v1.json`.
- Component and text-style creation remains paused. This avoids creating unverified aliases or silently substituting the missing approved fonts.
