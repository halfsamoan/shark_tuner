import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

const int referenceToneSampleRate = 48000;

final class ReferenceToneWave {
  const ReferenceToneWave({
    required this.bytes,
    required this.samples,
    required this.sampleRate,
    required this.sampleCount,
    required this.cycleCount,
    required this.actualFrequencyHz,
  });

  final Uint8List bytes;
  final Int16List samples;
  final int sampleRate;
  final int sampleCount;
  final int cycleCount;
  final double actualFrequencyHz;
}

ReferenceToneWave buildReferenceToneWave(
  double frequencyHz, {
  int sampleRate = referenceToneSampleRate,
  Duration minimumDuration = const Duration(seconds: 2),
}) {
  if (!frequencyHz.isFinite || frequencyHz < 20 || frequencyHz > 8000) {
    throw ArgumentError.value(
      frequencyHz,
      'frequencyHz',
      'Must be finite and within 20..8000 Hz.',
    );
  }
  if (sampleRate < 8000 || sampleRate > 192000) {
    throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  if (minimumDuration <= Duration.zero) {
    throw ArgumentError.value(minimumDuration, 'minimumDuration');
  }

  final minimumSeconds = minimumDuration.inMicroseconds / 1000000;
  final cycleCount = math.max(1, (frequencyHz * minimumSeconds).ceil());
  final sampleCount = (cycleCount * sampleRate / frequencyHz).round();
  final actualFrequencyHz = cycleCount * sampleRate / sampleCount;
  final samples = Int16List(sampleCount);
  const outputGain = 0.42;
  for (var index = 0; index < sampleCount; index++) {
    final phase = 2 * math.pi * cycleCount * index / sampleCount;
    final value =
        outputGain *
        (0.62 * math.sin(phase) +
            0.24 * math.sin(phase * 2) +
            0.10 * math.sin(phase * 3));
    samples[index] = (value * 32767).round().clamp(-32768, 32767);
  }

  final bytes = Uint8List(44 + sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, sampleCount * 2, Endian.little);
  for (var index = 0; index < sampleCount; index++) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }

  return ReferenceToneWave(
    bytes: bytes,
    samples: samples,
    sampleRate: sampleRate,
    sampleCount: sampleCount,
    cycleCount: cycleCount,
    actualFrequencyHz: actualFrequencyHz,
  );
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    bytes[offset + index] = value.codeUnitAt(index);
  }
}

abstract interface class ReferenceTonePlayer {
  Future<void> play(double frequencyHz);
  Future<void> stop();
  Future<void> dispose();
}

typedef ReferenceTonePlayerFactory = ReferenceTonePlayer Function();

ReferenceTonePlayer createReferenceTonePlayer() {
  return AudioplayersReferenceTonePlayer();
}

final class AudioplayersReferenceTonePlayer implements ReferenceTonePlayer {
  AudioplayersReferenceTonePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(double frequencyHz) async {
    final wave = buildReferenceToneWave(frequencyHz);
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(
      BytesSource(wave.bytes, mimeType: 'audio/wav'),
      volume: 0.55,
      mode: PlayerMode.mediaPlayer,
    );
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
