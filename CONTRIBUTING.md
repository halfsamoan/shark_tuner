# DSP, build, and validation

## Workspace

| Path | Responsibility |
|---|---|
| `app/` | Flutter UI, tuning sessions, and DSP isolate integration |
| `packages/tuner_audio/` | Capture abstraction and platform adapters |
| `packages/tuner_dsp/` | Pure-Dart detector and tracking pipeline |
| `packages/tuner_domain/` | Tuning definitions, peg direction, tension, and stability logic |
| `packages/tuner_data/` | Song metadata, search, and local storage |

`PitchDetector` and `AudioCapture` are the replacement boundaries. DSP and domain packages do not depend on Flutter UI code.

## Build environment

From PowerShell at the repository root:

```powershell
.\tool\bootstrap.ps1
.\tool\check.ps1
```

The bootstrap prepares Flutter and workspace dependencies. The check script runs formatting, analysis, tests, and the configured accuracy reports. Android release signing is an independent local setup; signing material must remain outside Git.

## Capture and detection

The Android path requests mono PCM and tests whether `UNPROCESSED` produces a usable signal. It falls back to `VOICE_RECOGNITION` when the sanity check fails and forwards the actual runtime sample rate to DSP.

The detector implements MPM from the algorithm's published description rather than porting a GPL implementation. The pipeline includes FFT autocorrelation, interpolation, clarity gating, octave handling, median smoothing, and cents-domain EMA. String selection and in-tune locking remain separate state machines.

## Measurement parameters

| Parameter | Configured value |
|---|---|
| Internal sample rate | 48,000 Hz mono |
| Detection lower bound | 43 Hz |
| High-pass cutoff | 30 Hz |
| Standard analysis window / hop | 4,096 / 1,536 samples |
| Low-tuning analysis window | 8,192 samples |

Changes to measurement thresholds must update the relevant tests and acceptance criteria together. A frequency floor or window length is not an accuracy result.

## Separate evaluation tracks

| Track | Input | What it establishes |
|---|---|---|
| Synthetic | Controlled sine-wave corpus | Deterministic detector regression behavior |
| Recorded guitar | Reference guitar WAV files | Response to recorded instrument timbre |
| Live device | Physical phone microphone input | Capture-path behavior, latency, and device-dependent error |

Do not combine the tracks into one product accuracy claim. Report octave errors and missing estimates separately from cent error. Existing historical measurements are not a new run on the current device.

## Instrument models

- Peg guidance uses a model of the headstock and winding direction; contradictory observations stop the guidance rather than inventing a direction.
- Tension calculation uses string unit weight, scale length, and target frequency. Wound strings require sourced unit-weight data rather than an arbitrary gauge approximation.
- Stability analysis separates attack overshoot, settling, drift, and signal quality. Output describes possible causes rather than confirmed mechanical diagnoses.
- Song selection transfers a versioned `TuningDefinition` snapshot so a changed catalog entry does not silently change an active session.

## Acceptance

Validate physical Android input, permissions, quiet/noisy capture, low strings, octave handling, clipping, and interruption recovery. UI validation includes small screens, enlarged text, TalkBack, and reduced motion. An iOS source adapter or project directory does not establish an iOS release.

Keep the detector implementation independent of GPL code. Song metadata must retain provenance, and distributed data must not include tabs or lyrics. Preserve dependency and font notices.
