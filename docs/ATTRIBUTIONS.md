# Third-party attributions

## Bundled interface fonts

toauner bundles four unmodified font files for its interface. The full license
texts ship in `app/assets/fonts/licenses/` and are registered with Flutter's
`LicenseRegistry` at startup.

- D2Coding 1.3.2 Regular and Bold, copyright NAVER Corporation. Source:
  [official release](https://github.com/naver/d2codingfont/releases/tag/VER1.3.2).
  License: SIL Open Font License 1.1; reserved font names `D2Coding` and
  `D2Coding-Bold`.
- Pretendard 1.3.9 Regular and SemiBold, copyright Kil Hyung-jin. Source:
  [official release](https://github.com/orioncactus/pretendard/releases/tag/v1.3.9).
  License: SIL Open Font License 1.1; reserved font name `Pretendard`.

The font files are not modified or renamed. D2Coding is used for numeric and
instrument-data roles; Pretendard is used for Korean prose and controls.

## Runtime audio playback

- `audioplayers` 6.8.1 and its federated platform packages, maintained by the
  Blue Fire team. Source: [bluefireteam/audioplayers](https://github.com/bluefireteam/audioplayers).
  License: MIT. toauner uses its local in-memory byte-source playback and loop
  mode for reference tones; it does not use remote audio URLs.

## DSP corpus data

toauner does not vendor third-party source code from the datasets below. The
Guitar-TECHS and NSynth WAV fixtures under
`packages/tuner_dsp/test/fixtures/public/` are modified excerpts used only for
DSP regression analysis. Each output's source path, source SHA-256, transforms,
and output SHA-256 are recorded in the adjacent provenance manifest.

The same fixture directory also contains 19 project-provided user recordings.
They are not derived from either public dataset, are not marked CC BY, and use
the rights value `project_provided_user_recording`. Their capture and reference
method is documented in `docs/user-guitar-corpus-2026-07-13.md`.

## Guitar-TECHS

- Title: *Guitar-TECHS: An Electric Guitar Dataset Covering Techniques,
  Musical Excerpts, Chords and Scales Using a Diverse Array of Hardware*
- Authors: Hegel Emmanuel Pedroza Villalobos, Termeh Taheri, Wallace Abreu,
  Ryan Corey, and Iran R. Roman. The paper citation supplied with the dataset
  lists Hegel Pedroza, Wallace Abreu, Ryan M. Corey, and Iran R. Roman.
- Publication: ICASSP 2025, DOI
  [10.1109/ICASSP49660.2025.10887996](https://doi.org/10.1109/ICASSP49660.2025.10887996)
- Dataset: [Zenodo record 14963133](https://zenodo.org/records/14963133),
  version v1
- License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- Local source subset: P1 and P2 single-note DI, amplifier-microphone, and MIDI
  files
- Modifications: MIDI note slicing, energy-based onset correction within the
  dataset's documented alignment tolerance, channel 0 selection after exact
  equality verification for stereo sources, PCM24/PCM16 conversion to mono
  PCM16, and 1.5-second excerpts

Archive checksums published by the dataset record and copied into the
provenance manifest:

- `P1_singlenotes.zip`: `ca0c4674dde3805574685a313f7c39eb`
- `P2_singlenotes.zip`: `40fbf03d8b04bb2cf42df20f36dc2254`

## NSynth

- Dataset: [The NSynth Dataset](https://magenta.withgoogle.com/datasets/nsynth),
  test split
- Paper: Jesse Engel, Cinjon Resnick, Adam Roberts, Sander Dieleman, Douglas
  Eck, Karen Simonyan, and Mohammad Norouzi. *Neural Audio Synthesis of
  Musical Notes with WaveNet Autoencoders* (2017),
  [arXiv:1704.01279](https://arxiv.org/abs/1704.01279)
- License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- Local source subset: guitar-family examples at MIDI 29-40 from the official
  16 kHz PCM16 test split; the subset contains both acoustic and electronic
  instrument-source labels
- Modifications: deterministic subset selection, canonical mono PCM16 WAVE
  encoding, and a separately labeled 48 kHz version regenerated from the 16
  kHz original with cubic Hermite interpolation (`cubic_hermite_resample_v1`)

NSynth pitch labels are nominal MIDI notes, not calibrated sub-cent reference
frequencies. Notes below a physical instrument's range may also originate from
sample-library pitch shifting. They are used for detector robustness and
sample-rate behavior, not as evidence for live low-string accuracy.

## String tension reference facts

- Official reference: [Stringjoy String Tension Calculator](https://tension.stringjoy.com/),
  nickel-wound electric-guitar measurements and the published ideal-string
  calculation, checked 2026-07-14
- Formula cross-check: D'Addario,
  [*All About String Tension*](https://www.daddario.com/blogs/guitar/all-about-string-tension),
  using `T = UW × (2 × L × F)² / 386.4`
- Local model: `stringjoy-nickel-roundwound-log-fit` version 1
- Use: selected physical measurements were used as calibration facts for a
  project-owned, bounded piecewise log interpolation model. toauner does not
  vendor the calculator source code, reproduce its full measurement table, or
  reproduce its page design or text.
- Verification: twenty official calculator outputs rounded to 0.1 lbf are
  stored as test expectations; every model result must remain within 3%.

String and manufacturer names remain trademarks of their owners. toauner is
not affiliated with or endorsed by Stringjoy or D'Addario. The recommended
generic sets are engineering estimates and do not claim identical feel across
brands, core shapes, or winding materials.
