# Third-party data attributions

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
