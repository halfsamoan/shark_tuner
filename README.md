<img src=".github/assets/icon.png" alt="SharkTune" width="88">

# SharkTune

An Android guitar tuner with pitch tracking, song-specific tunings, and instrument setup guidance.

[Android release and checksums](https://github.com/halfsamoan/shark_tuner/releases/tag/v1.0.0)

## Implementation

- **Pitch detection:** implements MPM in Dart with FFT autocorrelation, interpolation, a separate low-tuning analysis path, and octave-error handling.
- **Audio capture:** checks the Android input path and PCM signal before accepting measurements, with an `UNPROCESSED` to `VOICE_RECOGNITION` fallback.
- **Tracking and UI:** runs sustained DSP work outside the UI isolate and separates pitch smoothing, physical-string selection, and in-tune locking.
- **Instrument logic:** models peg direction, string tension, and tuning stability separately from the detector.

Song selection passes a versioned tuning definition into the session. Song metadata includes provenance; tabs and lyrics are not distributed. The internal workspace name is `toauner`.

[MPM detector](packages/tuner_dsp/lib/src/detectors/mpm_detector.dart) · [Audio capture](packages/tuner_audio/lib/src/record_audio_capture.dart) · [Tuning session](packages/tuner_domain/lib/src/tuning_session.dart)

## Install and use

Download the APK from the release page, allow installation from the app opening the file, and grant microphone access on first launch. Pluck one string and follow its pitch and cent deviation. Select a song to use its tuning targets.

An iOS distribution package is not included in the Android release.

## Measurement scope

Synthetic signals, recorded guitar WAVs, and live device input are evaluated separately. Synthetic detector accuracy is not presented as accuracy across all guitars, microphones, or phones. Stability diagnostics describe possible causes rather than confirming a mechanical fault.

[DSP, build, and validation guide](CONTRIBUTING.md)

## License

[MIT](LICENSE). Dependencies, fonts, and song metadata retain their [individual notices](docs/ATTRIBUTIONS.md).
