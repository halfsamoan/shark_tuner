## FINDINGS
# Flutter Real-Time Audio Capture for a High-Accuracy Guitar Tuner (Android-first, researched July 2026)

## 1. Package landscape (maintenance status as of July 2026)

### record (llfbandit) — v7.1.1, published ~2 weeks ago
- Verified publisher (cow-level.ovh), 885 likes, 160 pub points, ~754k downloads. Clearly the best-maintained general audio-capture plugin in the Flutter ecosystem.
- Streaming: `startStream(RecordConfig(...))` returns `Stream<Uint8List>`. Stream encoders: **pcm16bits** (all platforms) and aacLc. **No float PCM stream** — 16-bit only (96 dB dynamic range; fine for a tuner).
- `RecordConfig` defaults: encoder aacLc, sampleRate 44100, numChannels 2, and critically `autoGain: false`, `echoCancel: false`, `noiseSuppress: false` — the DSP-hostile effects are OFF by default, but set them explicitly anyway since "may not be considered on all platforms."
- **`AndroidRecordConfig.audioSource` exposes the full MediaRecorder.AudioSource enum**: `defaultSource, mic, voiceUplink, voiceDownlink, voiceCall, camcorder, voiceRecognition, voiceCommunication, remoteSubMix, unprocessed, voicePerformance`. Also `useLegacy` (MediaRecorder fallback), `muteAudio`, `manageBluetooth` (default true — consider disabling so a Bluetooth headset mic doesn't hijack capture), `speakerphone`, `audioManagerMode`.
- Android backend: AudioRecord (+ MediaCodec for compressed formats); min SDK 23. iOS: AVFoundation, iOS 12+.

### flutter_recorder (Marco Bavagnoli / marcobavagnoli.com, verified) — v1.1.6, published 7 days ago
- 89 likes, 160 pub points, Apache-2.0. From the author of flutter_soloud; very actively maintained.
- Native **miniaudio C library via FFI** (AAudio-backed on Android) — audio callback runs on a native thread, data crosses to Dart via FFI, not platform channels.
- **Float32 capture supported** (`f32le`, plus u8/s8/s16le/s24le/s32le), `sampleRate` and `channels` in `init()`.
- **`androidInputPreset`**: `voiceCommunication, camcorder, voiceRecognition, unprocessed` (maps to AAudio input presets).
- Extras useful for a tuner: `uint8ListStream` (`Stream<AudioDataContainer>`), built-in `getFft()`/`getWave()` (256-bin — too coarse for ±1 cent, use only for visualization), silence detection with dB threshold via callback/stream (useful for your "tuning stability / pitch drift" feature gating).
- Caveat: no documented control of buffer size/callback interval; default sampleRate 22050 (set explicitly); FFI/native crashes are harder to debug than a Kotlin channel.

### mic_stream — v0.7.2, last stable release ~16 months ago (early 2025)
- Unverified publisher, 99 likes, **GPL-3.0 license — effectively a deal-breaker for a closed-source commercial app**. Exposes `audioSource`, sampleRate, 8/16-bit PCM (float experimental). Not recommended.

### flutter_audio_capture — v1.1.12, ~6 months old
- Unverified publisher, 33 likes, MIT. Delivers Float64List via callback with `sampleRate` and `bufferSize` params. **No Android audio source selection** — disqualifying for tuner accuracy. Commonly paired with pitch_detector_dart in tutorials, but the AGC problem remains.

### audio_streamer (cachet.dk, verified) — v4.3.0, ~10 months old
- 45 likes, MIT. `Stream<List<double>>`, `sampleRate` + `actualSampleRate` properties (nice pattern worth copying). **No audio source selection.** Not suitable as primary.

### Others
- flutter_sound: streams Float32/Int16 PCM but heavyweight and has a documented issue of inconsistent/random stream chunk sizes regardless of requested bufferSize (issue #1118) — a pattern that applies broadly: **do not assume fixed chunk sizes from any Flutter capture stream; re-buffer in Dart.**
- flutter_pitch_detection (TarsosDSP wrapper): Android-only, no iOS path — useful reference, not a capture foundation. flutter-fft (Slins-23): a hobbyist tuner plugin, stale.

## 2. Android audio source — the accuracy-critical decision

- **Default `MIC` source**: OEMs may apply AGC, noise suppression, and echo cancellation in the HAL. AGC in particular destroys tuner amplitude stability and NS can eat sustained periodic tones (it looks like stationary "noise"). Must not ship on MIC/default.
- **`UNPROCESSED` (API 24+)**: bypasses platform pre-processing and, per CDD 5.11, devices that advertise support must also provide approximately flat frequency response and specified sensitivity/noise floors. Support is advertised via `AudioManager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"`. If the device does NOT advertise support, requesting UNPROCESSED silently falls back to default processing — i.e., you may get an AGC'd stream while believing you asked for raw audio.
- **Known field bug**: some Samsung devices return **silence** on the UNPROCESSED preset (google/oboe issue #1006). So even the property check is not sufficient — you need a runtime signal sanity check.
- **`VOICE_RECOGNITION`**: the canonical tuner fallback. The Android CDD (section 5.4, unchanged for years through current CDDs) requires that devices "MUST, by default, disable any noise reduction audio processing" and "MUST, by default, disable any automatic gain control" for VOICE_RECOGNITION. AOSP pre-processing guidance confirms NS must not be enabled by default for this source or the device fails compatibility. Available on every API level you target, and gives near-raw audio on compliant devices.
- **Recommended fallback chain**: (1) if `PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED` → try UNPROCESSED; (2) run a 1-2 s RMS/energy sanity check after starting — if the stream is all-zero/near-silent while the user is prompted to play a string, restart with VOICE_RECOGNITION; (3) VOICE_RECOGNITION as default everywhere else; (4) plain MIC only as last resort, with AGC compensation caveats. Persist the working source per device. Both `record` and `flutter_recorder` let you implement this chain in Dart; only the property check needs a ~10-line platform-channel call (or a plugin like `system_info`-style query).

## 3. Buffer sizes, callback cadence, isolates, latency

- Capture config: **mono, 44.1 or 48 kHz, 16-bit** (record) or float32 (flutter_recorder). Full rate, not 16 kHz — you want headroom for harmonic analysis up to several kHz; data rate is trivial (88-96 kB/s mono 16-bit).
- Chunk sizes from Flutter capture streams are **not guaranteed fixed** (flutter_sound #1118 documents random chunk sizes; record makes no cadence guarantee either). Architecture: treat the stream as a byte hose → push into a **ring buffer** → run analysis on fixed windows.
- Window/hop math for your low-note targets: F#1 = 46.2 Hz → 21.6 ms period. Autocorrelation/YIN-family detectors want ≥2-4 periods: **4096 samples @ 48 kHz = 85 ms (minimum), 8192 = 171 ms (better for ±1-cent stability at A1/F#1)**. Hop 1024-2048 samples → 20-45 UI updates/s, which reads as fully live. Note the display latency floor is set by the analysis window, not the capture path.
- Native-side buffer: AudioRecord minimum buffers are typically 10-40 ms; ask for 2-4x `getMinBufferSize` to avoid overruns — capture-side latency of 20-50 ms is irrelevant next to the ~100-170 ms analysis window.
- **DSP placement**: platform-channel/FFI stream events arrive on the root isolate. Do NOT run pitch detection inline in the stream listener — GC pauses and UI jank couple both ways. Pattern: long-lived worker isolate (`Isolate.spawn`, SendPort transfer of `Uint8List`, which is a cheap move for TypedData) doing ring buffer + YIN/MPM + your drift analysis, posting compact results (freq, cents, confidence, RMS) back at hop cadence. For ±1 cent with 8192-sample windows, pure Dart YIN/MPM is comfortably fast on any 2020+ phone; drop to Rust/C via FFI later only if profiling says so. Community guidance consistently recommends isolates for FFT-class work; end-to-end audio latencies "below 20 ms" targets quoted for live effects do NOT apply to a tuner — you have no monitoring path.

## 4. Oboe/AAudio vs AudioRecord (if writing our own platform code)

- Oboe = C++ wrapper over AAudio (API 27+) / OpenSL ES (older); its headline win is low-latency full-duplex (MMAP exclusive mode, ~2-burst buffers) for instruments/effects — i.e., **output latency**, which a tuner doesn't have.
- For **input-only at tuner timescales, java/Kotlin AudioRecord is entirely sufficient**: same audio sources (UNPROCESSED/VOICE_RECOGNITION), same data, ~200 lines of Kotlin for a custom plugin, far easier to debug than NDK code, no ABI/packaging burden.
- If you want native-callback capture anyway, flutter_recorder already gives you AAudio (via miniaudio) without writing NDK code. Reserve Oboe for a hypothetical future feature that needs duplex audio (e.g., reference-tone playback while capturing with echo concerns).

## 5. Permissions UX & Play Store (Android 13+/14+)

- RECORD_AUDIO remains a standard runtime "dangerous" permission: manifest entry + runtime dialog (permission_handler or record's built-in `hasPermission()`). Since Android 11: "Only this time" one-time grants (re-prompt next session) and auto-reset of unused apps' permissions; after two denials the dialog stops appearing — detect `permanentlyDenied` and deep-link to app settings. Since Android 12: green mic-indicator dot and Privacy Dashboard attribution — expected behavior, nothing to do.
- **No foreground service needed** for a foreground-only tuner. Use a screen wakelock (e.g. wakelock_plus) so the screen stays on while tuning. If you ever add background listening: Android 14+ requires `foregroundServiceType="microphone"` in the manifest + `FOREGROUND_SERVICE_MICROPHONE` permission + FGS-type declaration in Play Console (Policy > App content); mic FGS cannot be started from background (while-in-use restriction). Avoid this whole surface for MVP.
- Play policy: microphone apps need a **privacy policy** (store listing + in-app) and an accurate **Data safety form**. If audio is processed on-device in real time and never stored/transmitted (your case), it qualifies as ephemeral processing — you can generally declare no audio data collected, but say so explicitly in the privacy policy. "Prominent disclosure + consent" requirements trigger only if mic data is collected/shared, not for local ephemeral processing. RECORD_AUDIO is not in the SMS/Call-log-style hard-restricted set, but Google has been auto-auditing data-safety declarations against runtime behavior since late 2024, and a policy update announced for April 2026 continues tightening sensitive-permission review — keep the mic usage rationale in the store listing.

## iOS notes (secondary)
- Both record and flutter_recorder support iOS. The iOS analog of the AGC problem: set `AVAudioSession` mode to `.measurement` to minimize system input processing; verify what `IosRecordConfig` exposes when you get there (record exposes AVAudioSession category options). iPhone mics roll off below ~100 Hz too — same missing-fundamental handling applies.

## RECOMMENDATION
**MVP capture stack: the `record` package (v7.x) as primary, with an explicit Android audio-source fallback chain. No custom platform code for MVP.**

Concrete setup:
1. `record` with `startStream(RecordConfig(encoder: pcm16bits, sampleRate: 48000, numChannels: 1, autoGain: false, echoCancel: false, noiseSuppress: false, androidConfig: AndroidRecordConfig(audioSource: <chosen>, manageBluetooth: false)))`.
2. Source selection at first run: tiny MethodChannel call reading `AudioManager.getProperty(PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED)`; if "true" start with `AndroidAudioSource.unprocessed`, else `voiceRecognition`. After start, run a signal sanity check (RMS over ~1-2 s while prompting the user to pluck); on a dead stream (known Samsung UNPROCESSED bug) transparently restart on `voiceRecognition`. Persist the winning source per device. Never ship on default/MIC.
3. Pipe the `Uint8List` stream into a long-lived DSP isolate: ring buffer → 8192-sample analysis window (needed for ±1 cent at A1/F#1), 1024-2048 hop (~20-45 result updates/s) → send back {freq, cents, confidence, RMS} structs. This isolate is also where tuning-stability/pitch-drift tracking lives.
4. Permissions: `record.hasPermission()` (or permission_handler) with a pre-permission explainer screen; handle one-time grants and permanent denial (settings deep link). Wakelock instead of any foreground service. Data safety form: no data collected (ephemeral on-device processing) + privacy policy.

Fallback plan, in order:
- **Plan B — flutter_recorder** (verified, updated days ago, Apache-2.0): if record's stream cadence or 16-bit limit proves problematic, it gives float32 capture, AAudio-native callbacks via miniaudio/FFI, `androidInputPreset.unprocessed/voiceRecognition`, and silence detection. Main unknowns: no buffer-size control and FFI-level debugging.
- **Plan C — custom platform channel** (~200 lines Kotlin): AudioRecord + chosen AudioSource + fixed-size reads on a dedicated thread, EventChannel or dart:ffi ring buffer to Dart. AudioRecord is fully sufficient for input-only; do NOT invest in Oboe/AAudio NDK code for a tuner — its low-latency wins are for output/duplex paths you don't have.

Avoid: mic_stream (GPL-3.0, stale), flutter_audio_capture and audio_streamer (no audio-source control).

## RISKS
1. **UNPROCESSED device fragmentation**: devices without PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED silently fall back to processed audio, and some Samsung models return pure silence on UNPROCESSED (google/oboe #1006). The runtime signal sanity check + persisted per-device fallback is mandatory, not optional; test matrix must include Samsung.
2. **Sample rate and chunk-size promises are soft**: Android may deliver a different actual sample rate than requested on some devices, and Flutter capture streams (record, flutter_sound, etc.) deliver variable-size chunks. Verify actual rate at runtime (cents error scales directly with an assumed-wrong sample rate) and never build DSP assuming fixed callbacks.
3. **record streams 16-bit PCM only** (no float). Adequate SNR for ±1 cent, but if you later want float pipelines, that forces flutter_recorder or custom code.
4. **Phone mic low-frequency roll-off**: most handset mics attenuate heavily below ~100 Hz, so A1 (55 Hz) and F#1 (46.2 Hz) fundamentals may be weak-to-absent even with a flat UNPROCESSED path. Your ±1 cent claim at drop-A/8-string depends on a harmonics-aware detector (missing-fundamental handling), not just clean capture — capture stack alone cannot guarantee it.
5. **VOICE_RECOGNITION CDD compliance is "by default" only**: OEMs must disable NS/AGC by default on that source, but real-world HALs occasionally deviate; keep a device-report telemetry hook (opt-in) or a user-facing "raw input" toggle for support cases.
6. **Ecosystem churn**: mic_stream is stale and GPL; flutter_recorder is young (v1.x) with API still moving; record is a solo-maintainer project — pin versions and wrap capture behind your own interface so backends are swappable (this also gives you the iOS measurement-mode seam later).
7. **Play policy drift**: Google announced further policy changes effective April 2026 and actively audits Data safety declarations against runtime behavior; re-check mic/data-safety requirements at each release. If background tuning is ever added, the Android 14+ microphone FGS type + Play Console declaration becomes a real compliance surface.
