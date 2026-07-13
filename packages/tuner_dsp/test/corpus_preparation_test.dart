import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';

import '../tool/support/corpus_preparation.dart';

void main() {
  group('parseMidiNotes', () {
    test('applies tempo changes while pairing note events', () {
      final midi = _midiFile(
        ticksPerQuarter: 480,
        events: [
          _metaEvent(0, 0x51, [0x07, 0xa1, 0x20]),
          _channelEvent(480, [0x90, 40, 100]),
          _metaEvent(0, 0x51, [0x03, 0xd0, 0x90]),
          _channelEvent(480, [0x80, 40, 0]),
          _metaEvent(0, 0x2f, const []),
        ],
      );

      final notes = parseMidiNotes(midi);

      expect(notes, hasLength(1));
      expect(notes.single.midiNote, 40);
      expect(notes.single.velocity, 100);
      expect(notes.single.startSeconds, closeTo(0.5, 1e-9));
      expect(notes.single.endSeconds, closeTo(0.75, 1e-9));
    });
  });

  group('decodePcmWave', () {
    test('reads a selected channel from signed PCM24 stereo', () {
      final wave = decodePcmWave(
        _pcmWave(
          sampleRateHz: 48000,
          bitsPerSample: 24,
          channels: const [
            [4194304, -4194304],
            [2097152, -2097152],
          ],
        ),
        channel: 1,
      );

      expect(wave.sampleRateHz, 48000);
      expect(wave.sourceChannelCount, 2);
      expect(wave.sourceBitsPerSample, 24);
      expect(wave.samples[0], closeTo(0.25, 1e-7));
      expect(wave.samples[1], closeTo(-0.25, 1e-7));
    });

    test('identifies RIFF WAVE by content instead of filename extension', () {
      final bytes = _pcmWave(
        sampleRateHz: 44100,
        bitsPerSample: 16,
        channels: const [
          [0, 1, -1],
        ],
      );

      expect(isRiffWave(bytes), isTrue);
      expect(
        isRiffWave(Uint8List.fromList(ascii.encode('not audio'))),
        isFalse,
      );
    });
  });

  test('cubic resampling preserves original samples at an integer ratio', () {
    final output = resampleCubic(
      Float64List.fromList([0, 0.5, -0.25, 1]),
      sourceRateHz: 16000,
      targetRateHz: 48000,
    );

    expect(output, hasLength(12));
    expect(output[0], closeTo(0, 1e-12));
    expect(output[3], closeTo(0.5, 1e-12));
    expect(output[6], closeTo(-0.25, 1e-12));
    expect(output[9], closeTo(1, 1e-12));
  });

  test('cubic resampling preserves a 440 Hz tone from 44.1 to 48 kHz', () {
    const sourceRate = 44100;
    const targetRate = 48000;
    final input = Float64List(sourceRate);
    for (var index = 0; index < input.length; index++) {
      input[index] = math.sin(2 * math.pi * 440 * index / sourceRate) * 0.5;
    }

    final output = resampleCubic(
      input,
      sourceRateHz: sourceRate,
      targetRateHz: targetRate,
    );
    var positiveCrossings = 0;
    for (var index = 1; index < output.length; index++) {
      if (output[index - 1] <= 0 && output[index] > 0) {
        positiveCrossings++;
      }
    }

    expect(output, hasLength(targetRate));
    expect(positiveCrossings, 440);
  });

  test('level analysis reports full-scale clipping without normalization', () {
    final levels = analyzePcmLevels(Float64List.fromList([0, 1, -1, 0.25]));

    expect(levels.peakDbfs, closeTo(0, 1e-12));
    expect(levels.clippedSampleCount, 2);
    expect(levels.clippedSampleRate, 0.5);
  });

  test('attack alignment finds the energy rise around the MIDI onset', () {
    final samples = Float64List(2000);
    for (var index = 1030; index < 1500; index++) {
      samples[index] = index.isEven ? 0.8 : -0.8;
    }

    final aligned = alignAttackSample(
      samples,
      sampleRateHz: 1000,
      expectedSample: 1000,
      searchBeforeMs: 100,
      searchAfterMs: 150,
    );

    expect(aligned, inInclusiveRange(1025, 1035));
  });

  test('attack discovery finds an onset without a timestamp hint', () {
    final samples = Float64List(2000);
    for (var index = 1030; index < 1500; index++) {
      samples[index] = index.isEven ? 0.8 : -0.8;
    }

    final attack = findAttackSample(samples, sampleRateHz: 1000);

    expect(attack, inInclusiveRange(1025, 1035));
  });

  test(
    'representative selection is deterministic across pitch and velocity',
    () {
      final notes = [
        _note(midi: 40, velocity: 20, start: 2),
        _note(midi: 40, velocity: 100, start: 1),
        _note(midi: 45, velocity: 60, start: 3),
        _note(midi: 45, velocity: 120, start: 4),
      ];

      final selected = selectRepresentativeNotes(
        notes,
        targetMidiNotes: const [40, 45],
        targetVelocities: const [100, 50],
      );

      expect(selected.map((note) => note.midiNote), [40, 45]);
      expect(selected.map((note) => note.velocity), [100, 60]);
    },
  );
}

MidiNote _note({
  required int midi,
  required int velocity,
  required double start,
}) => MidiNote(
  channel: 0,
  endSeconds: start + 1,
  endTick: ((start + 1) * 1000).round(),
  midiNote: midi,
  startSeconds: start,
  startTick: (start * 1000).round(),
  velocity: velocity,
);

Uint8List _midiFile({
  required int ticksPerQuarter,
  required List<List<int>> events,
}) {
  final track = events.expand((event) => event).toList();
  final bytes = BytesBuilder(copy: false)
    ..add(ascii.encode('MThd'))
    ..add(_uint32(6))
    ..add(_uint16(0))
    ..add(_uint16(1))
    ..add(_uint16(ticksPerQuarter))
    ..add(ascii.encode('MTrk'))
    ..add(_uint32(track.length))
    ..add(track);
  return bytes.takeBytes();
}

List<int> _metaEvent(int delta, int type, List<int> payload) => [
  ..._variableLength(delta),
  0xff,
  type,
  ..._variableLength(payload.length),
  ...payload,
];

List<int> _channelEvent(int delta, List<int> payload) => [
  ..._variableLength(delta),
  ...payload,
];

List<int> _variableLength(int value) {
  final bytes = <int>[value & 0x7f];
  var remaining = value >> 7;
  while (remaining > 0) {
    bytes.insert(0, (remaining & 0x7f) | 0x80);
    remaining >>= 7;
  }
  return bytes;
}

List<int> _uint16(int value) => [value >> 8, value & 0xff];

List<int> _uint32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

Uint8List _pcmWave({
  required int sampleRateHz,
  required int bitsPerSample,
  required List<List<int>> channels,
}) {
  final channelCount = channels.length;
  final frameCount = channels.first.length;
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataLength = frameCount * channelCount * bytesPerSample;
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
  data.setUint32(
    28,
    sampleRateHz * channelCount * bytesPerSample,
    Endian.little,
  );
  data.setUint16(32, channelCount * bytesPerSample, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, dataLength, Endian.little);
  var offset = 44;
  for (var frame = 0; frame < frameCount; frame++) {
    for (var channel = 0; channel < channelCount; channel++) {
      final value = channels[channel][frame];
      for (var byte = 0; byte < bytesPerSample; byte++) {
        bytes[offset++] = (value >> (byte * 8)) & 0xff;
      }
    }
  }
  return bytes;
}
