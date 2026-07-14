# Reference tone playback

The reference-tone control lets a player hear the exact target for the
currently selected physical string. It is a listening aid, not another pitch
measurement path.

## Product contract

- The target comes from the active versioned `TuningDefinition`, including its
  A4 reference and song-level cents offset.
- Playback is a continuous local drone. Selecting another string while it is
  active replaces the drone with that string's target immediately.
- Microphone capture stops before speaker playback begins so toauner cannot
  detect its own output as a guitar string. The previous capture session is
  restored after the user stops the tone.
- The tuner clears measured cents and Hz while the drone is active and states
  that the microphone is paused. The control has an explicit TalkBack play or
  stop label and a 48 dp target.
- No audio is downloaded, uploaded, recorded, or retained by this feature.

## Signal contract

- Generated in memory as 48 kHz mono PCM16 WAVE.
- Each buffer contains an integer number of cycles. The buffer length is
  chosen from the requested frequency, so loop frequency error remains below
  0.01 cent across the supported guitar range and the loop boundary is
  phase-continuous.
- The timbre combines a restrained fundamental with second and third
  harmonics. This makes low guitar targets audible on phone speakers without
  changing the fundamental target.
- Playback gain is intentionally conservative and is also attenuated by the
  player volume control.

## Playback adapter

`ReferenceTonePlayer` is the replacement boundary. The production adapter uses
`audioplayers` 6.8.1 with an in-memory `BytesSource` and `ReleaseMode.loop`.
Tests use a fake adapter and never invoke a platform audio backend.

Verification covers deterministic WAVE output, header format, pitch error,
loop seam continuity, microphone pause/resume, cents-offset propagation, live
string switching, disposal, 2.0x text scale, and the no-scroll tuner contract.
