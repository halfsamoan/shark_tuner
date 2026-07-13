## FINDINGS
# 1. Tension formula — VERIFIED

**T = (UW × (2 × L × F)²) / 386.4** is confirmed verbatim on D'Addario's official "What Is Guitar String Tension?" page (daddario.com/blogs/guitar/all-about-string-tension):
- T = tension in pounds (lbf); multiply by 4.45 to get Newtons
- UW = unit weight in pounds per linear inch (lb/in)
- L = scale (vibrating) length in inches
- F = frequency in Hz
- Inverse form (used to pick a gauge for a target tension): **UW = (T × 386.4) / (2 × L × F)²**

Physical derivation (cross-checked at liutaiomottola.com/formulae/tension.htm): fundamental of an ideal string is f = (1/2L)·sqrt(T/μ), so T = μ·(2Lf)². Since UW is a *weight* per inch, mass density μ = UW/g, and **386.4 is g in inches/s²** (32.2 ft/s² × 12). Standard gravity is actually 386.088 in/s² (9.80665 m/s²); D'Addario's 386.4 rounding introduces ~0.08% error — irrelevant in practice, but use 386.4 if you want to reproduce their published numbers exactly. The relation holds for wound strings too, provided UW is the *measured* unit weight of the whole string (core + wrap). Metric equivalent: T(N) = μ(kg/m) × (2·L(m)·F(Hz))².

Sanity checks I computed against D'Addario's published chart values — all match:
- PL010 (.010 plain, UW 0.00002215) @ E4 329.63 Hz, 25.5" → 16.2 lbs
- NW046 (UW 0.00038216) @ E2 82.41 Hz, 25.5" → 17.5 lbs

# 2. Unit-weight data sources & legality

**Primary source:** D'Addario's tension chart PDF ("A complete technical reference for fretted instrument string tensions", tension_chart_13934.pdf) lists UW per item number (PL/NW/etc.) and tension per note/scale. Mirrors exist (kevinkastning.com/D'Addario_tension_chart.pdf). Their online String Tension Pro calculator supersedes it. Stringjoy (tension.stringjoy.com), Kalium (kaliummusic.com/string-tension-calculator, new version at stringtensioncalculator.com — best coverage of very heavy gauges), and GHS publish comparable data/calculators, but none publish a downloadable openly-licensed dataset.

**Verified sample of D'Addario XL unit weights (lb/in)** — extracted from a public GitHub mirror (KyleTaylorLange/StringTensionCalculator, json/DAddario.json), spot-matching the official chart:
- Plain steel: .007→0.00001085, .009→0.00001794, .010→0.00002215, .011→0.0000268, .013→0.00003744, .017→0.00006402
- Nickel wound: .026→0.00012671, .036→0.00023964, .042→0.00032279, .046→0.00038216, .052→0.00048109, .056→0.00057598, .059→0.00064191, .062→0.00070697, .064→0.00074984, .068→0.00084614, .074→0.00098869, .080→0.00115011

**Open-source implementations:**
- rodrigocfd/string-tension-calc (MIT license): does NOT ship the raw table; instead uses two polynomial fits UW = f(gauge) — one for plain, one for wound — fitted to the D'Addario catalog, plus multiscale support via linear interpolation of per-string scale length, plus a curated list of ~42 real commercial packs (D'Addario/Ernie Ball/Dunlop/Stringjoy-style). The exact polynomial coefficients are in src/model/consts.ts / funcs.ts and are MIT-reusable.
- KyleTaylorLange/StringTensionCalculator: ships the raw D'Addario JSON but has NO license file — don't copy its files verbatim; the numbers themselves are facts (below).

**Legality (US):** Under *Feist Publications v. Rural Telephone* (US Supreme Court, 1991), facts and measurements are not copyrightable; compilations get only "thin" protection over creative *selection and arrangement*. A unit weight (mass per inch of a physical object) is a measurement — a fact. Re-expressing those facts in your own data structure, or better, in a *derived model* (fitted curve), is generally considered legally safe in the US. What you must NOT do: reproduce the D'Addario PDF's layout/typography/text, copy their tables wholesale as images, or use their logos. Also cheap insurance: plain-string UW can be derived from first principles — UW = (π/4)·d²·ρ with steel ρ ≈ 0.285 lb/in³ gives 0.0000224 for .010 vs D'Addario's 0.00002215 (≈1% error) — so only wound strings genuinely need empirical data, and a power-law/polynomial fit across manufacturers is your own original work.

# 3. Comfortable tension ranges & how they shift

- Consensus comfortable range (25.5" E standard): **plain strings 13–18 lbs, wound strings 17–24 lbs**; a common overall sweet spot quoted is 14–20 lbs. Total set tension on 6-string electrics: ~95–130 lbs.
- **Balanced-tension design** (D'Addario BT sets, e.g. EXL110BT = 10-13.5-17-25-34-46): deviation between strings ≤ ~1 lb; general rule from Stringjoy/D'Addario: wound strings should sit ~2–4 lbs *above* the plains; the dropped string in a drop tuning should be within ~2–4 lbs of its neighbor.
- **Floppiness floor** (SevenString.org consensus for low tunings): below ~12–13 lbs a wound low string "flops" — audible pitch wobble on attack (directly relevant to your tuning-stability feature). Typical metal targets for the lowest string: **16–18 lbs minimum, 18–20 lbs preferred**; some doom/sludge players accept 13–14. The famous "floppy low B" reference point: D'Addario's stock 7-string .059 @ B1, 25.5" = 16.4 lbs.
- **Scale length**: T ∝ L², so vs 25.5": 24.75" → −5.8%, 26.5" → +8.0%, 27" → +12.1%, 28.625" → +26.0%. Multiscale = per-string effective length, linearly interpolated between treble and bass scale. This is why 8-string F#1 (46.25 Hz) is universally paired with 27"+ or multiscale; on 25.5" even an .080 (16.6 lbs) sounds undefined because inharmonicity/stiffness grows with gauge — tension alone understates the problem for very thick strings.
- Worked examples (25.5", D'Addario UW): .046 @ Drop-C C2 = 11.0 lbs (floppy — why 10-46 fails Drop C); .056 @ C2 = 16.6 lbs; .059 @ B1 = 16.5 lbs; .062 @ A1 = 14.4 lbs (loose-ish; = 16.1 lbs at 27"); .064 @ A1 = 15.3; .068 @ A1 = 17.2; .080 @ F#1 27" = 18.6 lbs.

# 4. Common gauge sets & tuning consensus

6-string: 9-42 (EXL120 / Super Slinky), 9-46 hybrid, 10-46 (EXL110 / Regular Slinky), 10-52 (EXL140 / Skinny Top Heavy Bottom), 10.5-48 (EXL110+), 11-49 (EXL115) / 11-48 (Power Slinky), 11-54 (Beefy Slinky), 11-56 (EXL117), 12-56 (Not Even Slinky), 12-60 (EXL148), 12-62 wound-G (Ernie Ball **Mammoth Slinky** — marketed for C standard / B standard / Drop A), 13-72 (Baritone Slinky), Stringjoy "Drop" series (Drop 11s 11-58, Drop 12s = 12-16-20p-34-46-64 for Drop C/B/A), 12-64 Stringjoy Drop A/B.
7-string: 9-54 (EXL120-7 / Super Slinky 7), 10-56 (Regular Slinky 7), **10-59 (EXL110-7 — the default Drop A set)**, 10-62/11-64 for tighter Drop A.
8-string: **9-65 (EXL120-8)**, 9-80 (Ernie Ball 8-string Heavy Bottom), 10-74 (common F#1/Drop E choice), Strandberg Optimized 9-84.

Per-tuning consensus @25.5" (forums: Ultimate Guitar, SevenString, Harmony Central + manufacturer marketing):
- Drop D: 10-46 acceptable, 10-52 preferred
- Drop C#/D standard: 11-54 (Beefy Slinky's stated purpose) or 11-56
- Drop C: 11-56 / 11-58; 10-52 loose, 12-56 tight (Not Even Slinky is EB's Drop C pick)
- Drop B: 12-56 – 12-60 (Stringjoy Drop 12s, EXL148)
- Drop A (6-str, A1=55 Hz): 12-62 (Mammoth) / 12-64 / 13-65, strongly prefer 26.5"+
- 7-string Drop A: 10-59 min, 10-62 preferred
- 8-string F#1/Drop E: 9-65 min @27", 10-74 preferred

# 5. Recommendation logic (validated pattern from rodrigocfd + Stringjoy guidance)

Reference algorithm confirmed workable: per-string effectiveScale(i) = trebleScale + i·(bassScale−trebleScale)/(n−1); UW from lookup-or-fit; T_i = UW(gauge_i)·(2·L_i·F_i)²/386.4; classify each string against thresholds; score candidate sets against a target tension profile. Details in Recommendation.

## RECOMMENDATION
## Data model (embed as versioned JSON/SQLite assets in the Flutter app)

1. **UnitWeightModel** — two-tier:
   - Plain steel: computed, UW = (π/4)·d²·0.285 lb/in³ (no dataset needed, ~1% accurate).
   - Wound (nickel-plated steel roundwound baseline): fitted power law/polynomial UW = f(d), calibrated against D'Addario NW values (or reuse the MIT-licensed polynomial coefficients from rodrigocfd/string-tension-calc). Store optional per-construction multipliers later (pure nickel ≈ +2–3%, stainless ≈ −1%, flatwound heavier) — v1 can ship roundwound-only with a "estimates ±5%" disclaimer.
   - Keep an override table keyed by (brand, itemCode) for exact values where you have them; fall back to the fit. Fields: `gauge_in`, `construction` (plain|wound), `unit_weight_lb_per_in`, `source` (measured|fitted).

2. **GaugeSet**: `{ id, displayName, brandFamily (generic like "10-52 skinny-top/heavy-bottom" + optional commercial aliases), numStrings, strings: [{gauge, construction}], tags: [balanced|heavy-bottom|drop|baritone] }`. Seed with the ~25 sets listed in findings §4; the rodrigocfd PACKS list is an MIT-licensed ready-made seed.

3. **Tuning**: `{ id, name, notes: [midiNote…] }` — derive F = 440·2^((midi−69)/12); reuse the same tuning table your tuner presets already need.

4. **Instrument**: `{ numStrings, scaleTreble_in, scaleBass_in }` (equal for non-multiscale); per-string L_i by linear interpolation.

## Logic

- `tensionLbs(i) = UW(gauge_i, construction_i) × (2 × L_i × F_i)² / 386.4` (use 386.4, not 386.088, to match D'Addario numbers players will cross-check).
- **Classification bands** (defaults, user-adjustable "feel" slider): floppy < 14 lbs wound / < 12 lbs plain; comfortable 14–22; tight > 24 plain / > 28 wound. Show a red/amber/green bar per string — this pairs naturally with your tuning-stability feature ("this string reads floppy AND drifts after picking").
- **Target profile**: take the user's current set at their *current* tuning as the reference feel (or default to 10-46 @ E standard, 25.5"), producing per-string target tensions. This "match your current feel at the new tuning" framing beats absolute thresholds.
- **Recommender**: for each candidate GaugeSet with matching string count, compute T_i at (target tuning, scale); score = Σ w_i·(T_i − target_i)² with extra weight on the lowest string, + large penalty for any string in the floppy band, + small penalty for plain↔wound G changes vs current set. Return top 3 with per-string tension tables and deltas.
- **Custom-set fallback**: per string solve UW_target = target_T × 386.4/(2·L·F)², invert the fit to a diameter, snap to nearest commercially available gauge (the GAUGES list in findings — .007–.084 electric), and label it "custom single-string set (Stringjoy/Kalium style)".
- Cap recommendations with rule-based guardrails from §4 consensus (e.g., never suggest < .059 for 7-string Drop A at ≤25.5") so outputs never contradict well-known community wisdom even if the pure math would allow it.

## RISKS
1. **Legal — low but not zero**: US: unit weights are facts (Feist), safe to use; but (a) do not reproduce D'Addario's PDF layout, text, or full tension tables as-published; (b) EU/UK sui generis database right protects "substantial investment" in obtaining/verifying data — a fitted curve (derived model) rather than a copied table is the clean answer and is what the MIT-licensed reference repo already did; (c) trademarks: naming sets "D'Addario EXL110", "Ernie Ball Not Even Slinky" is nominative fair use for compatibility, but add a "brand names are trademarks of their owners; not affiliated" disclaimer and lead with generic names ("10-46 regular").
2. **No truly open dataset exists** — the only licensed artifact found is the MIT polynomial-fit repo (rodrigocfd/string-tension-calc); the raw-JSON repo (KyleTaylorLange) has NO license, so re-derive or re-fit rather than copying its files.
3. **Accuracy limits of the formula**: ideal-string model; real feel also depends on core-to-wrap ratio (hex vs round core — a Stringjoy .046 ≠ D'Addario .046 in stiffness), and for very thick strings (>.068) inharmonicity/stiffness makes strings feel/sound worse than tension predicts — present numbers as estimates and keep the rule-based guardrails. Brand-to-brand UW variance on wound strings is ~5–10%.
4. **Fit extrapolation danger**: the reference polynomials were fitted on .007–.084; do not extrapolate to 8-string gauges beyond .084 (or bass gauges) without refitting — high-order polynomials diverge violently outside their fit range. A power law UW = a·d^b is safer for extrapolation.
5. **Scale-length subtlety**: actual vibrating length differs slightly from nominal scale due to saddle compensation (+1–3 mm bass side); negligible for recommendations but will cause small mismatches if users compare against measured tension.
6. **Community thresholds are contested**: "floppy" ranges from 13 to 18 lbs depending on genre — ship thresholds as user-tunable defaults, not hard truths, or reviews will call the app wrong.
7. Could not text-extract the official D'Addario PDF in this environment (image-based scan, no poppler/pypdf available); unit weights were instead verified via a public mirror JSON that spot-matches known chart values (PL010 @ E4/25.5" = 16.2 lbs, NW046 @ E2 = 17.5 lbs). Before shipping, re-verify the embedded table against String Tension Pro output for a handful of strings.
