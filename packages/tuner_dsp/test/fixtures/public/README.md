# Public DSP corpus fixtures

This directory contains 20 small CC BY 4.0 excerpts generated from
Guitar-TECHS and NSynth. It is intentionally a baseline corpus, not the G1
calibrated-reference gate.

The four classes are `guitartechs-di`, `guitartechs-amp`,
`nsynth-low-16k`, and `nsynth-low-48k`, with five fixtures in each class.
`manifest.public.v1.json` records source and output hashes plus every material
transform. See `docs/ATTRIBUTIONS.md` for citations and license notices.

Regenerate the exact selection from ignored local sources at the repository
root:

```powershell
.\.tools\flutter\bin\dart.bat run tool\prepare_corpus.dart --profile=ci
```

Run the informational detector baseline from `packages/tuner_dsp`:

```powershell
& ..\..\.tools\flutter\bin\dart.bat run tool\public_corpus_report.dart
```

The public datasets provide nominal semitone labels only. Therefore the report
separates valid estimates, octave errors, nominal-note deviation, and
within-clip self-consistency. It must remain informational until a reviewed
baseline and thresholds are added to `docs/accuracy-spec.md`.
