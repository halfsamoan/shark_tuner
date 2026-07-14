// (Claude) Metronome click engine. Synthesizes a whole-bar WAV (accent + beats
// with exact silence padding) and loops it through audioplayers, so timing is
// driven by the audio hardware loop rather than a drift-prone Dart timer.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

const int metronomeSampleRate = 48000;

/// Builds a click track (beat 1 of each bar accented) as a 48 kHz mono PCM16
/// WAV. The pattern is repeated to fill at least [minLoopDuration] so that the
/// (non-gapless) MediaPlayer loop boundary is rare; every beat inside the
/// buffer is sample-accurate, keeping the tempo steady.
Uint8List buildMetronomeBarWav({
  required int bpm,
  required int beatsPerBar,
  int sampleRate = metronomeSampleRate,
  Duration minLoopDuration = const Duration(seconds: 45),
}) {
  if (bpm < 20 || bpm > 400) {
    throw ArgumentError.value(bpm, 'bpm', 'Must be within 20..400.');
  }
  if (beatsPerBar < 1 || beatsPerBar > 12) {
    throw ArgumentError.value(beatsPerBar, 'beatsPerBar');
  }
  final samplesPerBeat = (sampleRate * 60 / bpm).round();
  final barSamples = samplesPerBeat * beatsPerBar;
  final minSamples = (sampleRate * minLoopDuration.inMilliseconds / 1000)
      .round();
  final bars = math.max(1, (minSamples / barSamples).ceil());
  final samples = Int16List(barSamples * bars);
  for (var bar = 0; bar < bars; bar++) {
    for (var beat = 0; beat < beatsPerBar; beat++) {
      final accent = beat == 0;
      _writeClick(
        samples,
        offset: bar * barSamples + beat * samplesPerBeat,
        sampleRate: sampleRate,
        frequencyHz: accent ? 1760 : 1320,
        gain: accent ? 0.9 : 0.62,
      );
    }
  }
  return _wrapWav(samples, sampleRate);
}

void _writeClick(
  Int16List samples, {
  required int offset,
  required int sampleRate,
  required double frequencyHz,
  required double gain,
}) {
  // Short decaying sine — a clean tick with a fast exponential envelope.
  const clickMs = 22;
  final clickSamples = math.min(
    sampleRate * clickMs ~/ 1000,
    samples.length - offset,
  );
  for (var i = 0; i < clickSamples; i++) {
    final t = i / sampleRate;
    final env = math.exp(-t * 140);
    final value = gain * env * math.sin(2 * math.pi * frequencyHz * t);
    samples[offset + i] = (value * 32767).round().clamp(-32768, 32767);
  }
}

Uint8List _wrapWav(Int16List samples, int sampleRate) {
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes[at + i] = s.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes;
}

abstract interface class MetronomePlayer {
  Future<void> play({required int bpm, required int beatsPerBar});

  /// (Claude) Current playback offset, used to keep the beat indicator locked
  /// to the audio timeline rather than a free-running visual timer.
  Future<Duration> position();

  Future<void> stop();
  Future<void> dispose();
}

typedef MetronomePlayerFactory = MetronomePlayer Function();

MetronomePlayer createMetronomePlayer() => AudioplayersMetronomePlayer();

final class AudioplayersMetronomePlayer implements MetronomePlayer {
  AudioplayersMetronomePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play({required int bpm, required int beatsPerBar}) async {
    final wav = buildMetronomeBarWav(bpm: bpm, beatsPerBar: beatsPerBar);
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    // (Claude) mediaPlayer mode loops a BytesSource reliably; lowLatency
    // (SoundPool) churns audio focus and does not sustain the looped bar.
    await _player.play(
      BytesSource(wav, mimeType: 'audio/wav'),
      volume: 1,
      mode: PlayerMode.mediaPlayer,
    );
  }

  @override
  Future<Duration> position() async =>
      (await _player.getCurrentPosition()) ?? Duration.zero;

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
