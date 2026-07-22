# Guitar Tuner App — Implementation Architecture

## 1. Project structure: feature-first, multi-package monorepo

Single Git repo, Melos-managed Dart workspace. The DSP core and audio capture live in **separate local packages** with zero Flutter dependencies where possible — this is what makes the future C++/FFI swap and the iOS port mechanical rather than a rewrite.

```
tuner/
├── melos.yaml
├── packages/
│   ├── tuner_dsp/                  # PURE DART, no Flutter import at all
│   │   ├── lib/src/
│   │   │   ├── api/
│   │   │   │   ├── pitch_detector.dart        # abstract PitchDetector  ← THE SEAM
│   │   │   │   ├── pitch_estimate.dart        # PitchEstimate value type
│   │   │   │   └── detector_config.dart
│   │   │   ├── detectors/
│   │   │   │   ├── mpm_detector.dart          # primary (clean-room from McLeod 2005)
│   │   │   │   └── yin_detector.dart          # cross-check (clean-room from de Cheveigné 2002)
│   │   │   ├── pipeline/
│   │   │   │   ├── ring_buffer.dart
│   │   │   │   ├── windower.dart              # fixed-window/hop extraction
│   │   │   │   ├── preprocessor.dart          # DC removal, 30 Hz HPF, optional decimate-by-2
│   │   │   │   ├── onset_detector.dart        # RMS-jump onset + hold-off
│   │   │   │   ├── estimate_stabilizer.dart   # confidence gate, octave check, median-of-5, EMA
│   │   │   │   └── pluck_analyzer.dart        # overshoot/settle/drift metrics (stability feature)
│   │   │   └── ffi/
│   │   │       └── ffi_pitch_detector.dart    # M3+: same PitchDetector interface, native impl
│   │   └── test/fixtures/*.wav                # recorded string samples (see §5)
│   ├── tuner_dsp_native/           # M3+: C++ core (sevagh/pitch-detection + pffft), CMake,
│   │                               # ffigen bindings. Android .so now, iOS .xcframework later.
│   ├── tuner_audio/                # capture abstraction (Flutter plugin consumer)
│   │   └── lib/src/
│   │       ├── audio_capture.dart             # abstract AudioCapture  ← second seam
│   │       ├── record_audio_capture.dart      # impl over `record` v7
│   │       └── source_selector.dart           # UNPROCESSED/VOICE_RECOGNITION fallback chain
│   ├── tuner_data/                 # models + drift database + repositories, no UI
│   └── tuner_domain/               # tension math, note mapping, peg-direction logic — pure Dart
└── app/
    └── lib/
        ├── main.dart
        ├── core/                   # theme, routing (go_router), l10n, haptics service
        └── features/
            ├── tuner/              # main screen: controller, needle, headstock, string pips
            ├── tunings/            # preset picker, custom tuning editor
            ├── instrument_setup/   # first-run wizard, InstrumentProfile editor
            ├── peg_guidance/       # arrow rendering, direction model, runtime sanity check
            ├── tension/            # gauge recommendation UI
            ├── stability/          # 30-s stability check flow + per-string cards
            ├── songs/              # song library search/browse, "tune for this song"
            └── settings/
```

**Where DSP lives:** pure Dart in `tuner_dsp` for MVP (MPM primary + YIN cross-check, FFT-accelerated with `fftea`, per the pitch research). **The seam** is the `PitchDetector` interface plus the fact that the whole detection pipeline runs inside an isolate owned by `tuner_audio`+`tuner_dsp` glue code — the UI never sees anything below `TunerFrame` (defined in §2). Swapping to FFI later means adding `FfiPitchDetector implements PitchDetector` and changing one factory:

```dart
abstract interface class PitchDetector {
  PitchEstimate? estimate(Float32List window, double sampleRate);
}

class PitchEstimate {
  final double frequencyHz;
  final double confidence;      // NSDF clarity or 1 - d'min, normalized 0..1
  final DetectorId detector;
}
```

Because `FfiPitchDetector` is stateless-per-call behind the same interface and the native lib is built as a plain CMake target in `tuner_dsp_native`, the iOS port is: compile the same C++ to an xcframework + write the `record` iOS config (`.measurement` AVAudioSession mode). No UI or pipeline changes.

---

## 2. Audio pipeline end-to-end

```
[record plugin: AudioRecord, UNPROCESSED→VOICE_RECOGNITION fallback]
        Stream<Uint8List> (pcm16, 48 kHz, mono, variable chunks)  — root isolate
                    │  SendPort (Uint8List transfer = cheap move)
                    ▼
┌──────────────── DSP ISOLATE (long-lived, spawned once) ────────────────┐
│ RingBuffer(32768)                                                       │
│   └─ Windower: 4096-sample windows, hop 1536 (~31 updates/s)            │
│        (8192-sample window when preset's lowest target < 60 Hz)         │
│        └─ Preprocessor: DC block, 30 Hz HPF                             │
│             └─ OnsetDetector: RMS gate + 50 ms attack hold-off          │
│                  └─ MpmDetector (+ YinDetector agreement bonus)         │
│                       └─ EstimateStabilizer: confidence gate (>0.9),    │
│                          octave sanity vs f/2, median-of-5, EMA α=0.3   │
│                            ├─ NoteMapper (target tuning + A4 ref +      │
│                            │  cents offset) → cents error, string guess │
│                            └─ PluckAnalyzer → PluckEvent metrics        │
│   emits TunerFrame every hop ────────────────────────────────────────►  │
└─────────────────────────────────────────────────────────────────────────┘
                    │  SendPort (small struct)
                    ▼
   root isolate: TunerEngine (facade) → Stream<TunerFrame>
                    ▼
   Riverpod: tunerFrameProvider → TunerController → widgets
```

**Concrete classes:**

- `AudioCapture` (abstract) / `RecordAudioCapture` — wraps `record` v7: `startStream(RecordConfig(encoder: pcm16bits, sampleRate: 48000, numChannels: 1, autoGain/echoCancel/noiseSuppress: false, androidConfig: AndroidRecordConfig(audioSource: chosen, manageBluetooth: false)))`. Exposes `Stream<Uint8List> pcm`, `double actualSampleRate`.
- `AudioSourceSelector` — one small MethodChannel reading `PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED`; runs the RMS sanity check after start (dead-stream → restart on `voiceRecognition`, the Samsung UNPROCESSED bug); persists winning source per device in settings.
- `DspIsolate` — spawn/handshake/teardown; receives `DspCommand` (start, stop, `SetTuningTarget`, `SetDetectorConfig`, `SetStringLock`), emits `TunerFrame` and `PluckEvent`.
- `RingBuffer`, `Windower`, `Preprocessor`, `OnsetDetector` — as diagrammed. Never assume fixed chunk sizes from the plugin; the ring buffer is the contract.
- `EstimateStabilizer` — owns the whole smoothing recipe and the two-stage smoothing (raw-fast when |error| > 10¢, heavy EMA inside).
- `NoteMapper` (in `tuner_domain`, pure) — `map(freqHz, TuningTarget) → NoteReading(midiNote, centsError, assignedString)`. Implements string-assignment hysteresis: switch only on fresh onset + M consecutive confident frames + >150¢ from current target; frozen once within ±15¢. Guided-retune mode uses per-string capture windows (±4 semitones) instead of nearest-target snapping.
- `InTuneLockDetector` (root isolate, inside `TunerController`) — post-attack median within tolerance held 750 ms → lock event → green flood/haptic/advance.
- `PluckAnalyzer` — per onset computes `attackOvershootCents`, `settleTimeMs`, `steadyStatePitchCents`, `driftCentsPerSec`, `peakRms`, `confidence`; emits `PluckEvent`.
- `StabilityLogger` (root isolate) — persists `PluckEvent`s to drift, runs `StabilityClassifier` (rule-based: new-strings / light-gauge / nut-binding / temperature hypotheses).
- `TunerFrame` — the only thing UI consumes: `{timestampMs, freqHz?, midiNote?, centsError?, assignedString?, confidence, rmsDb, isLocked, settling}`.

---

## 3. State management & persistence

**Riverpod (v3, with riverpod_generator + hooks).** Reasoning for a solo dev: the app's core is *streams flowing into derived state* (frame stream → note → lock state → peg hint), which is exactly `StreamProvider` + computed providers with almost no boilerplate; Bloc's event/state class ceremony pays off for large teams enforcing conventions, which you don't have. Riverpod also gives DI for free (swap `PitchDetector`/`AudioCapture` impls in tests via provider overrides — this is your test seam too) and compile-safe access without `BuildContext`. One `TunerController extends Notifier<TunerState>` per feature screen; everything else is derived providers.

**drift** (over sqflite/isar). Reasons: the song library *needs* SQLite FTS5 (drift supports it first-class; isar has its own index model and its maintenance history is shaky; raw sqflite means hand-writing everything); type-safe compiled queries and migrations matter for the versioned bundled song DB + delta-feed upserts; drift runs on NativeDatabase in a background isolate (no jank when the stability logger writes during tuning); and it's pure SQLite → trivially portable to iOS.

Stored in drift: `tunings` (presets + custom), `songs` + `songs_fts` (FTS5, shipped pre-built as an asset DB, attached/merged with the user DB), `gauge_sets`, `instrument_profiles`, `tuning_sessions`, `pluck_events`. Simple key-value settings (A4 ref, tolerance, theme, chosen audio source, per-peg overrides) in `shared_preferences` — no reason to over-model those.

---

## 4. Data models (in `tuner_data`, mirrored as drift tables)

```dart
class Tuning {
  final String id;                 // 'drop-d'
  final String name;
  final int stringCount;           // 6|7|8|4(bass)|4(uke)
  final List<int> midiNotes;       // low→high, e.g. [38,45,50,55,59,64]
  final TuningFamily family;       // standard|drop|open|modal|custom
  final double centsOffset;        // global offset (Eb-and-a-bit cases live on SongEntry)
  final bool isUserDefined;
}

class InstrumentProfile {
  final String id;
  final InstrumentType type;               // electric|acoustic|bass|ukulele|classical
  final int stringCount;
  final double scaleTrebleInches;          // == scaleBass for non-multiscale
  final double scaleBassInches;
  final HeadstockLayout headstock;         // threePlusThree|sixInLine|fourInLine|twoPlusTwo|slotted
  final bool leftHanded;
  final Map<int, PegDirectionOverride> pegOverrides;  // self-heal flipped pegs
  final StringGaugeSet? currentStrings;
}

class StringGaugeSet {
  final String id;
  final String displayName;                // "10-52 heavy bottom"
  final List<StringSpec> strings;          // [{gaugeInches, construction: plain|wound}]
  final List<String> commercialAliases;    // ["EXL140", "Skinny Top Heavy Bottom"] (+ TM disclaimer)
}
// Tension engine (tuner_domain): T = UW(g, construction) * (2*L_i*F)^2 / 386.4
// UW: plain = (π/4)d²·0.285; wound = power-law fit a·d^b calibrated to D'Addario NW,
//     with (brand,itemCode) override table. Never extrapolate the fit past .084.

class SongEntry {
  final String id;                         // 'foo-fighters-everlong'
  final String artist, title;
  final String tuningId;
  final int capo;                          // metadata only — "tune first, capo after"
  final double centsOffset;                // Van Halen +20, Pantera −25
  final String? gaugeHint;
  final List<LiveVariant> liveVariants;
  final Difficulty difficulty;
  final Confidence confidence;             // verified|high|medium
  final List<String> sources;
}

class PluckEvent {
  final int sessionId;
  final DateTime onsetTs;
  final int stringIndex;
  final double targetCents, peakRmsDb;
  final double attackOvershootCents, settleTimeMs;
  final double steadyStateCents, driftCentsPerSec;
  final double confidence;
  final bool stepJumpFlag;                 // nut-binding signature
}

class TuningSessionLog {
  final int id;
  final DateTime startedAt;
  final String tuningId, instrumentProfileId;
  final List<PluckEvent> plucks;           // relation
  final double sessionDriftCentsPerMin;    // computed
  final StabilityVerdict? verdict;         // newStrings|lightGauge|nutBinding|temperature|stable
}
```

---

## 5. Milestone plan

**M0 — Walking skeleton (2–3 weeks).** `record` capture with hardcoded VOICE_RECOGNITION → DSP isolate → Dart MPM (4096/hop 1536, parabolic interpolation) → raw needle + Hz/cents readout, chromatic only.
*Exit criteria:* E2–E4 sine sweeps read within ±1¢; real strummed E-standard guitar shows stable readings on 2 physical devices (one Samsung, one mid-range); needle latency pluck→movement < 150 ms; CPU < 20% of one core (profiled).
*Tests:* unit tests in `tuner_dsp` against **synthetic fixtures** (sines, sines+harmonics with weak fundamental, ±3¢ detuned) and **recorded WAV fixtures** — record now: each open string, 6/7-string, hard and soft picks, incl. A1/F#1 from a real downtuned guitar through a phone mic. Assert median error and gross-error (octave) rate per fixture. This corpus is the project's most valuable test asset; grow it every milestone.

**M1 — Solid tuner (4–5 weeks).** Preset tunings + custom editor, NoteMapper with string auto-detect + hysteresis, onset hold-off, full stabilizer chain, in-tune lock (±3¢/750 ms, tolerance setting), A4 reference 415–466, audio-source fallback chain + sanity check, drift DB, settings, dark/stage theme, wakelock, permission UX.
*Exit criteria:* full 6-string tune-up by a non-guitarist tester in < 90 s; zero wrong-string assignments across the fixture corpus replayed through the pipeline; octave-pair test (D2 vs D4, A1 vs A2 fixtures) passes; UNPROCESSED-silent device path verified by fault injection.
*Tests:* pipeline integration tests feeding WAV files through RingBuffer→TunerFrame (pure Dart, runs in CI); widget tests for lock/advance flow with a fake `TunerEngine` via Riverpod overrides; string-assignment property tests (sweep E2→A1, assert no mid-journey re-snap in guided mode).

**M2 — Differentiators (6–8 weeks).** Peg guidance (headstock rendering, direction model from (layout, side, handedness), curved arrows, quarter-turn hints, runtime direction sanity-check + per-peg flip); tension/gauge engine + recommender (target-profile scoring, floppy guardrails, top-3 sets, custom-set fallback); stability check flow (PluckAnalyzer, StabilityLogger, rule classifier, per-string cards phrased as hypotheses); song library (~80-song curated JSON → CI-compiled SQLite asset, FTS5 search, "tune for this song" flow with capo banner + guided retune + gauge warning).
*Exit criteria:* peg arrows verified correct on ≥4 real instruments (3+3, 6-in-line, lefty, classical); tension outputs match D'Addario String Tension Pro within 3% for 20 spot-checked strings; every [M]-confidence song human-verified or cut; stability metrics reproducible (same string, 5 plucks → overshoot σ < 30% after RMS normalization).
*Tests:* **golden tests for gauge math** (fixed table of (gauge, tuning, scale) → expected lbs, checked to 0.1 lb); peg-direction truth-table unit tests covering every layout×handedness×side cell; PluckAnalyzer tests on fixture WAVs with hand-labeled overshoot/settle values; song DB schema/FTS integration tests; classifier tests on synthesized drift scenarios.

**M3 — Polish + release (4 weeks).** FFI core (`tuner_dsp_native`: vendored sevagh/pitch-detection + pffft, ffigen, `FfiPitchDetector`, A/B parity test vs Dart impl on the fixture corpus — ship whichever wins profiling, keep Dart as fallback); 8192-window low-tuning mode; haptic/spoken accessibility modes + TalkBack labels; onboarding wizard; Play listing, privacy policy, Data-safety form (ephemeral, no collection); crash reporting (Sentry); version-pinned dependency audit (license check in CI: fail on GPL).
*Exit criteria:* FFI and Dart detectors agree within 0.5¢ on the full corpus; battery < ~8%/30 min tuning session; TalkBack walkthrough completes a tune-up; closed-track (20+ testers, incl. Samsung) with no P0s for 2 weeks; Play review passed.
*Tests:* FFI↔Dart parity suite (same WAVs, assert deltas); leak test on isolate/native buffer lifecycle (start/stop 100×); `flutter driver` smoke test on Firebase Test Lab device matrix.

---

## 6. Top 5 technical risks & mitigations

1. **Low-string accuracy on phone mics (F#1/A1, fundamentals 10–20 dB down, and Meshuggah-F1 at 43.6 Hz below the stated floor).** *Mitigation:* design the detector floor to 43 Hz, not 46; 8192-sample low-tuning mode; octave sanity check is load-bearing; M0 fixture corpus recorded on real cheap Androids, not synthetic-only; if ±1¢ proves unreachable at F1, UI degrades honestly ("settling…" state) rather than showing false precision.
2. **GPL contamination from the Flutter pitch ecosystem (TarsosDSP, pitch_detector_dart, flutter_pitch_detection, aubio, mic_stream).** *Mitigation:* clean-room MPM/YIN from the papers only, documented provenance; only MIT/BSL/Apache deps (sevagh/pitch-detection + pffft for FFI); automated license check in CI from M0.
3. **Android capture fragmentation (UNPROCESSED silent on Samsungs, OEM AGC on default source, soft sample-rate promises).** *Mitigation:* the mandatory fallback chain + post-start RMS sanity check + persisted per-device source; verify `actualSampleRate` at runtime (cents error scales directly with a wrong assumed rate); Samsung permanently in the test matrix; capture hidden behind `AudioCapture` so a custom Kotlin plugin (Plan C, ~200 lines AudioRecord) is a drop-in.
4. **Wrong peg-direction arrow destroys beginner trust (reversed headstocks, slotted classical, backwards-wound strings).** *Mitigation:* direction encoded as data (layout, side, handedness) not code; runtime sanity check — two contradictions between predicted and observed pitch direction offers a one-tap flip persisted per peg; hardware-verified truth table before M2 exit.
5. **Stability-analysis misdiagnosis (overshoot conflates pick strength with string condition; temperature mimics stretching).** *Mitigation:* normalize by `peakRms`, require ≥3 plucks per verdict, phrase all outputs as hypotheses with advice ("possible nut friction — try graphite"); ship rule thresholds as remotely-tunable config; collect opt-in labeled telemetry before any ML.

Secondary watch items: `record` is solo-maintained (pin + wrap), Songsterr API is curation-time-only (never a runtime dependency), Play data-safety policy re-check each release.