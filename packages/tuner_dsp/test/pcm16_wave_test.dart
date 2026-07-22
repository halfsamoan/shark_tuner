import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../tool/support/pcm16_wave.dart';

void main() {
  test('decodes mono PCM16 samples', () {
    final wave = decodePcm16Wave(
      _waveBytes(
        sampleRateHz: 48000,
        channels: const [
          [0, 16384, -16384],
        ],
      ),
    );

    expect(wave.sampleRateHz, 48000);
    expect(wave.sourceChannelCount, 1);
    expect(wave.monoSamples, [0, 0.5, -0.5]);
  });

  test('downmixes stereo frames before DSP analysis', () {
    final wave = decodePcm16Wave(
      _waveBytes(
        sampleRateHz: 44100,
        channels: const [
          [16384, -16384],
          [0, 16384],
        ],
      ),
    );

    expect(wave.sampleRateHz, 44100);
    expect(wave.sourceChannelCount, 2);
    expect(wave.monoSamples[0], closeTo(0.25, 0.00001));
    expect(wave.monoSamples[1], closeTo(0, 0.00001));
  });

  test('rejects floating-point WAVE input', () {
    final bytes = _waveBytes(
      sampleRateHz: 48000,
      channels: const [
        [0],
      ],
    );
    ByteData.sublistView(bytes).setUint16(20, 3, Endian.little);

    expect(() => decodePcm16Wave(bytes), throwsFormatException);
  });
}

Uint8List _waveBytes({
  required int sampleRateHz,
  required List<List<int>> channels,
}) {
  final channelCount = channels.length;
  final frameCount = channels.first.length;
  if (channels.any((channel) => channel.length != frameCount)) {
    throw ArgumentError('Channel lengths must match.');
  }
  final dataLength = frameCount * channelCount * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channelCount, Endian.little);
  data.setUint32(24, sampleRateHz, Endian.little);
  data.setUint32(28, sampleRateHz * channelCount * 2, Endian.little);
  data.setUint16(32, channelCount * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, dataLength, Endian.little);
  for (var frame = 0; frame < frameCount; frame++) {
    for (var channel = 0; channel < channelCount; channel++) {
      data.setInt16(
        44 + (frame * channelCount + channel) * 2,
        channels[channel][frame],
        Endian.little,
      );
    }
  }
  return bytes;
}
