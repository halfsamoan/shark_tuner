## FINDINGS
# 1. How top tuners present pitch — what makes a tuner FEEL accurate

## Display metaphors in the market
- **Needle (analog meter)**: the default for beginners — intuitive, instantly readable. Practical accuracy ceiling of app needles is ~±0.5–1 cent. Fender Tune and most apps use a needle or arc with a center marker.
- **Strobe (Peterson-style rotating bands)**: rotating segments whose apparent motion direction/speed encodes sharp/flat; Peterson claims 0.1-cent (hardware pedals 0.02-cent) resolution. Perceived as "the accurate one" because motion never fully stops until you are truly in tune — but it needs a short learning curve and has no obvious "done" state for beginners. Peterson StroboStomp HD pairs it with a full-screen color change (background turns green when in tune) to fix that.
- **GuitarTuna pattern**: large moving indicator + scrolling pitch-history trace over a realistic headstock graphic; auto string detection; when the indicator centers, a checkmark/confirmation fires and the app effectively tells you to move to the next string. Multiple 2025–26 roundups call it the beginner benchmark: "most new players have all six strings in tune within a minute of installing it."
- **TC PolyTune pattern**: strum all 6 strings, see all strings' offsets at once (poly view), then "MonoPoly" auto-switches to single-string chromatic/strobe when you pluck one string. Its clip-on/pedal also auto-adjusts LED brightness with an ambient light sensor — a pattern worth copying in software (auto stage/dark mode).

## What makes it FEEL accurate (synthesis of reviews + design writeups)
- **Stability beats raw resolution**: a needle that jitters ±3 cents feels broken even if the median is perfect. Top apps smooth (median-of-5 + exponential smoothing is a documented recipe, e.g. FrequencyDetector's chromatic tuner: YIN, 4096-sample window, octave-error correction, ~22 Hz update) and gate on confidence so the needle freezes rather than flails in silence/noise.
- **Fast response + smoothed display is the balancing act**: latency above ~100 ms between pluck and needle movement feels laggy; heavy smoothing feels "syrupy." The common solution is two-stage: raw fast movement during large errors, heavier smoothing inside ±10 cents.
- **A widening "in-tune" state change**: color shift (red/amber → green), a checkmark, a satisfying animation, a tick sound, and/or a haptic tap. Reviews consistently praise apps where the in-tune moment is unmistakable.

## In-tune lock criteria in practice
No vendor publishes an exact spec, but converging evidence:
- Green zone default **±5 cents** is called out explicitly (guitartuner.io: "the in-tune zone (green) opens at ±5 cents"); HarmonicTune exposes a user-set tolerance **±1 to ±15 cents**; TonalEnergy exposes RANGE presets (wide/medium/fine/ultra-fine) and only rewards the smiley face when pitch stays inside the range.
- Apps require the reading to be **held, not instantaneous** — TonalEnergy's smiley and GuitarTuna's checkmark fire after the pitch sits in the zone for a beat (observed behavior ~0.5–1 s of voiced, in-zone signal). ChromTuner fires "a gentle haptic tap the moment a string locks in."
- Cautionary tale: Fender Tune reviews complain the auto tuner is "overly exacting, taking a long time just to tune one string" — a lock criterion that is too strict measurably frustrates beginners.
- Best practice for us: display at ±1-cent resolution, default in-tune zone ±3 cents (beginner mode ±5, pro mode ±1–2), lock when the **post-attack median** pitch stays in-zone for ~750 ms of valid frames — and critically, exclude the attack transient from the lock decision (see §3), otherwise hard pickers can never lock.

# 2. Peg-direction guidance

## The rule and its consistency
- Physical basis: with standard winding (string exits the post on the side facing the headstock centerline), winding more string on raises pitch. This makes direction **consistent per side and mirrored between sides**.
- **3+3 (Les Paul, most acoustics)**: bass-side pegs (E-A-D) and treble-side pegs (G-B-E) turn **opposite** directions for the same pitch change. fretjam's beginner phrasing: "for pegs on the left, turn the peg away from you to tune the string up; for pegs on the right, it's the opposite." Equivalently (facing the front of the headstock): bass-side posts rotate counterclockwise to raise, treble-side clockwise.
- **6-in-line (Strat/Tele) and 4-in-line bass (P/J)**: all pegs on the bass side ⇒ **all turn the same direction** (counterclockwise viewed from the headstock front / "away from you" in playing position) to raise pitch.
- **2+2 ukulele**: mirror rule same as 3+3.
- **Exceptions that MUST be modeled**: left-handed and reversed headstocks (flip everything); slotted classical headstocks (horizontal rollers, different sightline); vintage-style bass "elephant ear" keys that face backwards (the visible button face is reversed relative to the post); users who wound a string backwards (breaks the rule for that one string). Locking tuners don't change direction.
- Conclusion: the rule IS consistent enough to encode as (headstock_layout, side, handedness) → direction, with a per-string override and a runtime sanity check: if the user turns and pitch moves opposite to prediction twice, offer to flip that peg's direction (this also self-heals backwards-wound strings).

## Visual UX
- GuitarTuna's headstock graphic that "even shows you which tuning peg to turn for each string" is repeatedly praised in reviews; Fender Tune's manual mode uses an authentic Strat headstock you tap. The winning pattern: render the user's actual headstock layout, highlight the target string's peg, animate a **curved arrow around the peg button in the true rotation direction**, with text like "String 3 (G) — turn the highlighted peg a quarter turn toward the arrow," plus a live "keep going / slow down / back a hair" state as pitch approaches target.
- Show magnitude as fraction-of-turn ("about a quarter turn"), never degrees or clockwise/counterclockwise words alone — beginners' viewpoint of "clockwise" is ambiguous depending on which side of the headstock the peg is on.

## Rotation ≈ cents heuristic
- Gear ratio definition (Guitar Kit World): an 18:1 tuner needs 18 button turns per full post revolution; budget tuners ~14:1, quality 18:1+, some 21:1.
- No published rotation-to-cents table exists; derived from string physics (f ∝ √T, semitone = +12.2% tension; plain-steel strain at pitch ~0.5–0.7% over ~0.7 m nut-to-post length; post Ø ~6 mm): **one semitone ≈ 10–12° of post rotation on plain strings ≈ 0.4–0.55 button turns at 14:1–18:1**; wound strings (lower core strain) need roughly half that, ~0.2–0.3 turns per semitone. Working heuristic: **a quarter turn of the button ≈ 40–60 cents on plain strings, ≈ 80–120 cents on wound strings**; ~1.5–2° of button rotation per cent on plain strings. These vary with gauge, scale length, post diameter and wrap count, so ship them as starting hints and calibrate per string in-session (observe cents-moved per user adjustment episode and scale the suggested fraction-of-turn accordingly).

# 3. Stability analysis heuristics (the differentiator)

## Attack transient physics
- Jack Endino's classic "Tuning Nightmares" article (engineer-grade observations): a plucked note reads **sharp instantly then settles** — on a hard-picked low E the needle "shoots all the way over to the right and then pulls slowly back." Effect grows with pick force, lighter gauge, lower tension; hard rhythm players on light strings can sit **10–15 cents sharp** through fast passages because strings never reach steady state. High strings show minimal glide.
- Academic literature calls this **pitch glide from tension-modulation nonlinearity**: pitch decays exponentially toward steady state, magnitude ≈ proportional to pluck energy; measured examples show glide durations around **1–1.5 s** on hard plucks. Practical tuning advice across sources: wait ~1 s and read the sustain, not the attack; there are long forum debates (Fractal Audio) on "tune to attack or decay" — consensus: decay/sustain, but note players who only ever hear their attack.
- Expected numbers to design around: overshoot **+5–30 cents** scaling with pluck amplitude and inversely with tension; settle time **0.3–1.5 s**; downtuned/low-tension setups (drop A, 8-string F#1 with too-light gauges) at the high end. This is exactly why the stability screen must pair with your string-gauge/tension recommendations.

## Cause classification signatures (from Endino, tuner.wiki, string-life sources)
- **New strings stretching**: monotonic FLAT drift across the whole session; goes out "five minutes later" after tuning; steel strings mostly settle after 1–2 hours of playing, full stability in 1–3 days; nylon 2–4 days up to a week. Signature: every string re-reads flat by a few cents each re-check, magnitude decaying over days.
- **Low tension / gauge too light for tuning**: large attack overshoot (+15–30 c), long settle, but stable steady state pluck-to-pluck. (Endino: heavier strings sharpen far less on attack.)
- **Nut binding / friction**: while tuning up, "the tuner will show no change, and then suddenly a tiny squeak" and pitch **jumps in a discrete step** past target (Endino); after bends/trem use, pitch lands sharp or flat abruptly, often with a "ping" (tuner.wiki). Signature: quantized pitch steps + hysteresis (direction-dependent error) rather than smooth drift.
- **Slipping windings / loose tuners**: goes flat after a single hard strum; gradual one-way drift; mechanical wiggle test.
- **Temperature/humidity**: all strings drift together — flat when warming up, sharp when cold; 15–20 min acclimation window. Signature: correlated multi-string drift.
- **Posture/neck flex** (Endino): low E visibly flattens when standing vs sitting — a confound to note, not classify.

## Prior art for tuning diagnostics
- **Roadie (Band Industries)**: the closest — the Roadie app "keeps track of your strings' quality and knows when to change strings," i.e., string-wear tracking from tuning-history data; Roadie 4 hardware auto-detects strings by vibration. It's device-tethered, not a pure-app pluck-level diagnostic.
- **Tronical/servo auto-tuners**: algorithms "predict and correct how each string will settle after tension changes" to land in one servo sweep — validates that settle prediction is tractable.
- **Peterson Sweetened Tunings**: 100+ presets that pre-compensate equal-temperament error and "string stretch" — prior art for compensating attack sharpness, not diagnosing it.
- **No mainstream app** currently gives per-pluck stability analytics (overshoot / settle / drift with cause hypotheses). This differentiator is genuinely open space; nearest neighbors are Roadie's string-life tracker and studio lore in Endino's article.

# 4. Auto string detection

- Standard pattern (documented by ChromTuner and matching GuitarTuna/Fender behavior): **Instrument mode** shows the selected tuning's string buttons and auto-detects which string you're playing, displaying cents from that string's target; **Chromatic mode** free-detects any note. Always offer manual string tap-to-lock as an escape hatch (both GuitarTuna and Fender Tune have it).
- **Failure modes, worse in downtunings**:
  - *Octave errors*: plucked-string energy shifts between fundamental and harmonics over the note's life, so raw detectors jump octaves — catastrophic for string mapping because guitar tunings contain octave pairs (7-string Drop A: string 7 = A1 55 Hz vs string 5 = A2 110 Hz; Drop D: D2 vs D4... an octave error maps to the WRONG STRING with high confidence). Octave-error correction (sub-harmonic checking against 2× / 0.5× candidates) is table stakes; YIN-family algorithms + harmonic-agreement checks are the documented approach.
  - *Mid-journey misassignment*: while tuning E2 down to A1 (a 7-semitone drop) the pitch sweeps past B1/C2, nearest-target logic will re-snap to string 5 (B1 on a 7-string) halfway down and start telling the user to tune UP. Fix: when the app knows the user is retuning to a new preset, run a **guided per-string flow keyed to the expected string**, with a wide capture window (±3–4 semitones) around each target and explicit "tune DOWN, you're way above target" messaging — don't use nearest-target snapping during large retunes.
  - *Adjacent-string ambiguity*: down at F#1 (46.2 Hz) targets are ~35 Hz apart in absolute terms but detection jitter and mic rolloff (phone mics roll off below ~80–100 Hz; you must detect low strings via harmonics 2–4, a documented low-frequency tuner problem) makes single frames unreliable — decide on multi-frame evidence only.
- **Hysteresis recipe** (synthesized; no app publishes theirs): keep the current string assignment until (a) another target is closer by a margin (e.g., detected pitch crosses 60–70% of the way to the neighbor's midpoint, roughly >±150 cents from current target), AND (b) that holds for M consecutive confident frames (~200–300 ms), AND (c) a fresh note onset occurred — never switch strings mid-sustain. Bias assignments by expected octave using harmonic-set agreement, and freeze assignment entirely once a string enters the "±15 cents, fine-tuning" phase.

# 5. Accessibility & non-visual confirmation

- **Haptics**: HarmonicTune ships distinct vibration patterns for flat / sharp / in-tune; ChromTuner gives a haptic tap on lock; HapTuner (research project) is a wrist-worn tuner using two vibration motors to encode sharp/flat/in-tune; Guitar World (2025) covered a blind guitarist whose life was changed by a vibrating haptic tuner pedal — strong evidence haptic tuning is both feasible and underserved. Android: use distinct waveforms (e.g., short double-tap = in tune; slow pulse = flat, speed encodes distance; fast pulse = sharp).
- **Audio/sonification**: Talking Tuner (iOS, VoiceOver-friendly) auto-speaks "note name + cents sharp/flat" after each pluck; Guita ("Guitar Tuner for Blind", iOS/Android) uses spoken status plus **beep intervals that accelerate as you approach pitch** (Geiger-counter pattern). These patterns also help sighted users on dark stages who don't want to stare at a screen.
- **Screen-reader**: full TalkBack labeling of the tuner state (string, note, cents, direction to turn) is rare in mainstream tuners — cheap differentiation. TonalEnergy advertises VoiceOver support; most competitors don't.
- **Dark-stage UI**: Fender Tune markets a "large, easy-to-read display perfect for dark stages"; PolyTune hardware auto-dims via ambient light sensor. App equivalents: true-black high-contrast stage theme, auto theme via ambient light, giant note glyph + cents readable at 1 m, keep-screen-awake while tuning, no white flashes.

## RECOMMENDATION
## MVP UX flow (screens)
1. **First-run setup (3 taps max)**: instrument (6/7/8-string, bass, uke) → headstock layout (3+3, 6-in-line, 4-in-line, 2+2, slotted; auto-suggested from instrument) + handedness → mic permission with one-line rationale. Powers peg guidance from minute one.
2. **Main tuner screen (the product)**: hybrid display — big needle/arc with ±1-cent numeric readout, plus a subtle scrolling pitch-trace (GuitarTuna-style) so users see the attack-glide settle; headstock graphic with the active string's peg highlighted and a curved animated arrow in the true rotation direction + "about a quarter turn" hint that shrinks as error shrinks; string pips showing tuned/untuned progress; auto string detect (preset-keyed, with tap-to-lock); in-tune lock = post-attack median within ±3 cents (beginner default ±5, pro ±1–2) held ~750 ms → green flood + checkmark + distinct haptic + optional tick, then auto-advance to next string.
3. **Tuning picker**: search + categories (Standard, Drop, Open, 7/8-string, Song library); selecting a lower tuning shows tension delta and gauge recommendation inline; entering a far-away tuning triggers the guided per-string retune flow (expected-string capture windows, "tune DOWN" messaging) instead of nearest-target snapping.
4. **Stability check (differentiator screen)**: after all strings lock, offer "Check tuning stability (30 s)" — pluck each string once, medium strength, let ring 3 s; show per-string card: attack overshoot (cents), settle time (ms), steady-state drift, and a cause chip (New strings stretching / Light gauge for this tuning / Possible nut binding / Stable) with one-line advice, linking to gauge recommendations.
5. **Pro chromatic mode**: strobe-style ribbon + numeric cents, A4 reference 415–466 Hz, transposition — satisfies advanced users without cluttering the beginner path.
6. **Settings**: tolerance slider (±1–±15 c like HarmonicTune), haptic/sound/voice toggles (spoken "E, 12 flat" mode for accessibility), stage/dark theme + auto-brightness theme switch, left-handed flip, per-peg direction override.

## Stability metrics to log per pluck (concrete definitions)
Per detected note onset, on the f0 track (10–20 ms hop) + RMS envelope:
- `onset_ts`, `string_id`, `target_cents`, `peak_rms` (normalizer — overshoot scales with pluck energy, so never compare overshoots across plucks without it).
- `attack_overshoot_cents` = median(f0, 50–150 ms post-onset) − steady_state_pitch. Expect +5–30 c; flag >25 c.
- `settle_time_ms` = first time f0 enters and stays within ±3 c of steady_state_pitch for ≥300 ms, measured from onset. Expect 300–1500 ms.
- `steady_state_pitch_cents` = median(f0) from settle until RMS < −30 dB of peak; `steady_state_drift_c_per_s` = robust linear slope over that window (within-note drift).
- `inter_pluck_drift_c` = steady_state delta vs previous pluck of same string; `session_drift_c_per_min` = slope across the session (new-string signature: consistently negative, decaying over days).
- `post_adjust_step_flag` = pitch changed in a discrete jump (>3 c between adjacent frames) immediately after peg movement or a bend — nut-binding signature, especially with direction-dependent hysteresis.
- `confidence` = f(YIN periodicity/clarity, SNR, fundamental-vs-harmonic agreement, valid-frame ratio); discard plucks with confidence < threshold rather than logging noise.
- Classification (rule-based v1): session_drift consistently flat on all strings → new strings; overshoot high + settle long but steady-state stable → low tension/heavy attack (recommend heavier gauge for this tuning); step jumps + hysteresis after tuning/bends → nut binding; correlated slow multi-string drift → temperature. Ship rules first, collect labeled data, consider ML later.

## Also adopt
- Runtime peg-direction sanity check: if observed pitch change contradicts the predicted arrow twice, offer to flip that peg's mapping (self-heals reversed winding/lefty errors).
- Rotation hints: seed quarter-turn ≈ 40–60 c (plain) / 80–120 c (wound), then calibrate per string from observed correction episodes.
- Exclude attack window from lock logic; low strings (A1/F#1) get longer analysis windows and harmonic-based detection (phone mics won't deliver the fundamental at 46 Hz).

## RISKS
- **Peg-direction wrong-arrow risk**: exceptions are real (left-handed/reversed headstocks, slotted classical rollers, rear-facing vintage bass keys, user-wound-backwards strings). A confident wrong arrow destroys beginner trust instantly. Mitigate with the runtime direction sanity check and per-peg override; validate each headstock art asset against real instruments.
- **No published lock-criteria specs**: the ±5 cents / hold-time numbers are assembled from app docs, settings ranges and observed behavior, not vendor specs — tune them with user testing. Fender Tune's reviews show the failure mode of too-strict locking (users report it "taking a long time just to tune one string").
- **Rotation-per-cent heuristic is soft**: varies ~3× with gear ratio, string type, post diameter, wrap count; present as "about a quarter turn," never as precise degrees, and calibrate in-session. The physics-derived numbers here are engineering estimates, not sourced measurements.
- **Low-frequency detection**: at F#1 (46.2 Hz) phone mics roll off below ~80–100 Hz; you must infer f0 from harmonics, windows get long (≥4096–8192 samples), and octave errors map to the WRONG STRING in tunings with octave pairs (Drop A: A1 vs A2). This is the hardest accuracy claim in the spec (±1 c stable at 46 Hz) — prototype early with real 8-string recordings on mid-range Android hardware.
- **Stability-metric confounds**: attack overshoot scales with pick strength, so raw values conflate player technique with string condition — must normalize by pluck amplitude and require multiple plucks; temperature and posture (neck flex) mimic drift signatures. Misdiagnosing "nut binding" when it's user error is a support burden — phrase causes as hypotheses ("possible nut friction — try graphite in the slots").
- **Sparse quantitative literature**: pitch-glide magnitudes (+10–30 c) and settle times (0.3–1.5 s) come from one engineer's article, tension-modulation acoustics papers, and forum consensus — collect your own labeled corpus (new vs old strings, gauges, tunings) before hard-coding classifier thresholds.
- **IP/trademark**: "Sweetened Tunings" is Peterson's; GuitarTuna's headstock look is its trade dress; strobe visuals are fine to imitate generically but avoid Peterson's exact pattern language. Roadie already tracks string wear (device-tethered) — expect them to notice a pure-app equivalent.
