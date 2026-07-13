# Recorded-guitar DSP corpus fixtures

This directory contains 39 small fixtures: 20 CC BY 4.0 excerpts generated
from Guitar-TECHS and NSynth, plus 19 project-provided user recordings. It is
an informational robustness baseline, not the G1 calibrated-reference gate.

The public-data classes are `guitartechs-di`, `guitartechs-amp`,
`nsynth-low-16k`, and `nsynth-low-48k`, with five fixtures in each class. The
`user-guitar` class contains all 19 derived recordings from session
`user-guitar-samsung-sm-s926n-20260713-v1`. User recordings are not CC BY data;
their rights are recorded as `project_provided_user_recording`.
`manifest.public.v1.json` records source and output hashes plus every material
transform. See `docs/ATTRIBUTIONS.md` for public-dataset citations and
`docs/user-guitar-corpus-2026-07-13.md` for the user session method.

Regenerate the exact selection from ignored local sources at the repository
root:

```powershell
.\.tools\flutter\bin\dart.bat run tool\prepare_corpus.dart --profile=ci
```

Run the informational detector baseline from `packages/tuner_dsp`:

```powershell
& ..\..\.tools\flutter\bin\dart.bat run tool\public_corpus_report.dart
```

All classes provide nominal semitone labels rather than calibrated sub-cent
references. Therefore the report separates valid estimates, octave errors,
errors over 50 cents, nominal-note deviation, and within-clip self-consistency.
For `user-guitar`, it also reports tuning, string, pick-strength, and clipping
segments. These results remain informational and cannot be used for product
accuracy claims or G1 passage.
