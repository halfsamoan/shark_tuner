# Android device profile — 2026-07-13

## Environment

- Device: Samsung SM-S926N
- Android: 16 / API 36
- Build: Flutter profile APK
- Capture: `UNPROCESSED`, actual 48,000 Hz, mono PCM16
- DSP execution: long-lived Dart isolate (`toauner-dsp`)

The app process CPU is not used as the DSP gate because it also contains UI,
raster, recorder, and platform work. The isolate worker was identified by
matching the active `DartWorker` TID with `/proc/<pid>/task/<tid>/comm`, then
confirming that its CPU time stopped advancing after leaving the tuner screen.

## Method

The steady-state samples were collected at one-second intervals with Android's
thread view:

```text
adb shell top -H -b -d 1 -n <samples> -p <app-pid> \
  -o PID,TID,%CPU,TIME+,CMDLINE
```

The first partial interval and the malformed terminal row emitted by this
Samsung `top` build were excluded. Percentages below are a fraction of one CPU
core for the DSP `DartWorker` only.

## Results

| Path | Window / hop | DSP TID samples | Mean | Status |
| --- | ---: | --- | ---: | --- |
| Standard tuning | 4096 / 1536 | 16, 22, 19, 17, 21, 19, 21, 23, 17, 19 | 19.4% | M0 CPU gate passes, narrowly |
| Low tuning | 8192 / 2304 | 21, 25, 20, 20, 18, 20, 20, 19, 22, 19, 21, 21, 22, 22 | 20.7% | Diagnostic only; does not pass 20% yet |

The subsequent M0 hardening change sets the low-tuning hop to 2,400 samples,
which is exactly 20 updates/s at 48 kHz. The earlier 20.7% row remains the
pre-change measurement and must not be relabeled as a passing result; the new
configuration requires a fresh device sample.

`tool/profile_android_dsp.ps1` now automates the same thread-view collection,
discards the first partial interval per worker, stores every sample in an
ignored JSON report, and optionally enforces the 20% mean gate. The highest
active `DartWorker` remains only a candidate until its CPU time is confirmed
to stop after leaving the tuner screen.

The precision tuner also accumulates repeated pluck-to-display samples. For a
valid latency run, mute the strings after each estimate, wait for the input to
fall quiet, and pluck again. The displayed p95 includes PCM onset-to-analysis
time plus detector processing time; at least 20 samples are required for the
device gate report.

The on-screen detector timer, which excludes PCM ingest, showed approximately
1.9–5.8 ms for warmed frames after FFT acceleration. A 10.9 ms transient was
seen immediately after one redeploy. Repeated builds and profiling warmed the
phone, so future comparisons should use a fixed thermal precondition and a
longer sample interval.

## Interpretation

- M0's default 4096 path meets the one-core DSP target on this device, but the
  margin is too small to generalize to other phones.
- The 8192 precision path is close but remains over the target. Its next safe
  optimization candidates are filtered decimation or the existing
  `PitchDetector` FFI seam; lowering the update cadence below the documented
  20 Hz floor is not counted as a solution.
- Pluck-to-first-valid latency and live guitar accuracy remain unmeasured until
  the recorded/live guitar corpus is available.
