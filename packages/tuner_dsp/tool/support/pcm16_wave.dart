import 'dart:convert';
import 'dart:typed_data';

final class Pcm16Wave {
  const Pcm16Wave({
    required this.sampleRateHz,
    required this.sourceChannelCount,
    required this.monoSamples,
  });

  final int sampleRateHz;
  final int sourceChannelCount;
  final Float64List monoSamples;
}

/// Decodes uncompressed little-endian PCM16 WAVE and downmixes to mono.
Pcm16Wave decodePcm16Wave(Uint8List bytes) {
  if (bytes.length < 44 ||
      _ascii(bytes, 0, 4) != 'RIFF' ||
      _ascii(bytes, 8, 4) != 'WAVE') {
    throw const FormatException('Expected a RIFF/WAVE file.');
  }
  final data = ByteData.sublistView(bytes);
  int? audioFormat;
  int? channelCount;
  int? sampleRateHz;
  int? bitsPerSample;
  int? dataOffset;
  int? dataLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = _ascii(bytes, offset, 4);
    final chunkLength = data.getUint32(offset + 4, Endian.little);
    final payloadOffset = offset + 8;
    if (payloadOffset + chunkLength > bytes.length) {
      throw FormatException('Truncated $chunkId chunk.');
    }
    if (chunkId == 'fmt ') {
      if (chunkLength < 16) {
        throw const FormatException('Invalid fmt chunk.');
      }
      audioFormat = data.getUint16(payloadOffset, Endian.little);
      channelCount = data.getUint16(payloadOffset + 2, Endian.little);
      sampleRateHz = data.getUint32(payloadOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(payloadOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = payloadOffset;
      dataLength = chunkLength;
    }
    offset = payloadOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
  }
  if (audioFormat != 1 ||
      channelCount == null ||
      channelCount <= 0 ||
      sampleRateHz == null ||
      sampleRateHz <= 0 ||
      bitsPerSample != 16 ||
      dataOffset == null ||
      dataLength == null) {
    throw const FormatException(
      'Only uncompressed PCM16 WAVE with a data chunk is supported.',
    );
  }
  final bytesPerFrame = channelCount * 2;
  if (dataLength % bytesPerFrame != 0) {
    throw const FormatException('PCM data does not contain complete frames.');
  }
  final frameCount = dataLength ~/ bytesPerFrame;
  final samples = Float64List(frameCount);
  for (var frame = 0; frame < frameCount; frame++) {
    var sum = 0.0;
    for (var channel = 0; channel < channelCount; channel++) {
      final sampleOffset = dataOffset + frame * bytesPerFrame + channel * 2;
      sum += data.getInt16(sampleOffset, Endian.little) / 32768.0;
    }
    samples[frame] = sum / channelCount;
  }
  return Pcm16Wave(
    sampleRateHz: sampleRateHz,
    sourceChannelCount: channelCount,
    monoSamples: samples,
  );
}

String _ascii(Uint8List bytes, int offset, int length) {
  return ascii.decode(bytes.sublist(offset, offset + length));
}
