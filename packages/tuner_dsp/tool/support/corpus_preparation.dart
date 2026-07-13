import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const double userGuitarFixtureGainDb = -3;
final double userGuitarFixtureLinearGain = math
    .pow(10, userGuitarFixtureGainDb / 20)
    .toDouble();

final class MidiNote {
  const MidiNote({
    required this.channel,
    required this.endSeconds,
    required this.endTick,
    required this.midiNote,
    required this.startSeconds,
    required this.startTick,
    required this.velocity,
  });

  final int channel;
  final double endSeconds;
  final int endTick;
  final int midiNote;
  final double startSeconds;
  final int startTick;
  final int velocity;
}

final class DecodedPcmWave {
  const DecodedPcmWave({
    required this.sampleRateHz,
    required this.samples,
    required this.sourceBitsPerSample,
    required this.sourceChannelCount,
  });

  final int sampleRateHz;
  final Float64List samples;
  final int sourceBitsPerSample;
  final int sourceChannelCount;
}

final class PcmLevelStats {
  const PcmLevelStats({
    required this.clippedSampleCount,
    required this.clippedSampleRate,
    required this.peakDbfs,
  });

  final int clippedSampleCount;
  final double clippedSampleRate;
  final double peakDbfs;
}

bool isRiffWave(Uint8List bytes) =>
    bytes.length >= 12 &&
    ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
    ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';

PcmLevelStats analyzePcmLevels(Float64List samples) {
  if (samples.isEmpty) {
    return const PcmLevelStats(
      clippedSampleCount: 0,
      clippedSampleRate: 0,
      peakDbfs: double.negativeInfinity,
    );
  }
  const clippingThreshold = 32767 / 32768;
  var peak = 0.0;
  var clippedSampleCount = 0;
  for (final sample in samples) {
    final magnitude = sample.abs();
    peak = math.max(peak, magnitude);
    if (magnitude >= clippingThreshold) {
      clippedSampleCount++;
    }
  }
  return PcmLevelStats(
    clippedSampleCount: clippedSampleCount,
    clippedSampleRate: clippedSampleCount / samples.length,
    peakDbfs: peak == 0
        ? double.negativeInfinity
        : 20 * math.log(peak) / math.ln10,
  );
}

Float64List applyFixedGain(Float64List samples, {required double gainDb}) {
  if (!gainDb.isFinite || gainDb > 0) {
    throw ArgumentError.value(
      gainDb,
      'gainDb',
      'Fixture gain must be finite and non-positive.',
    );
  }
  final gain = math.pow(10, gainDb / 20).toDouble();
  return Float64List.fromList([for (final sample in samples) sample * gain]);
}

List<MidiNote> parseMidiNotes(Uint8List bytes) {
  final reader = _ByteReader(bytes);
  if (reader.readAscii(4) != 'MThd') {
    throw const FormatException('Expected a Standard MIDI header.');
  }
  final headerLength = reader.readUint32BigEndian();
  if (headerLength < 6) {
    throw const FormatException('Invalid Standard MIDI header length.');
  }
  final format = reader.readUint16BigEndian();
  final trackCount = reader.readUint16BigEndian();
  final division = reader.readUint16BigEndian();
  if (format > 1 || division & 0x8000 != 0 || division == 0) {
    throw const FormatException(
      'Only PPQ Standard MIDI format 0 or 1 is supported.',
    );
  }
  reader.skip(headerLength - 6);

  final channelEvents = <_ChannelEvent>[];
  final tempoEvents = <_TempoEvent>[
    const _TempoEvent(tick: 0, microsecondsPerQuarter: 500000, order: -1),
  ];
  var order = 0;
  for (var trackIndex = 0; trackIndex < trackCount; trackIndex++) {
    if (reader.readAscii(4) != 'MTrk') {
      throw const FormatException('Expected an MTrk chunk.');
    }
    final trackLength = reader.readUint32BigEndian();
    final trackEnd = reader.offset + trackLength;
    if (trackEnd > bytes.length) {
      throw const FormatException('Truncated MTrk chunk.');
    }
    var tick = 0;
    int? runningStatus;
    while (reader.offset < trackEnd) {
      tick += reader.readVariableLength();
      var eventByte = reader.readUint8();
      int? firstDataByte;
      if (eventByte < 0x80) {
        if (runningStatus == null) {
          throw const FormatException('MIDI running status is missing.');
        }
        firstDataByte = eventByte;
        eventByte = runningStatus;
      }
      if (eventByte == 0xff) {
        runningStatus = null;
        final type = reader.readUint8();
        final length = reader.readVariableLength();
        if (type == 0x51 && length == 3) {
          final tempo =
              (reader.readUint8() << 16) |
              (reader.readUint8() << 8) |
              reader.readUint8();
          tempoEvents.add(
            _TempoEvent(
              tick: tick,
              microsecondsPerQuarter: tempo,
              order: order++,
            ),
          );
        } else {
          reader.skip(length);
        }
        continue;
      }
      if (eventByte == 0xf0 || eventByte == 0xf7) {
        runningStatus = null;
        reader.skip(reader.readVariableLength());
        continue;
      }
      if (eventByte < 0x80 || eventByte > 0xef) {
        throw FormatException(
          'Unsupported MIDI status 0x${eventByte.toRadixString(16)}.',
        );
      }
      runningStatus = eventByte;
      final kind = eventByte & 0xf0;
      final channel = eventByte & 0x0f;
      final dataLength = kind == 0xc0 || kind == 0xd0 ? 1 : 2;
      final data1 = firstDataByte ?? reader.readUint8();
      final data2 = dataLength == 2 ? reader.readUint8() : 0;
      if (kind == 0x80 || kind == 0x90) {
        channelEvents.add(
          _ChannelEvent(
            channel: channel,
            isNoteOn: kind == 0x90 && data2 > 0,
            midiNote: data1,
            order: order++,
            tick: tick,
            velocity: data2,
          ),
        );
      }
    }
    if (reader.offset != trackEnd) {
      throw const FormatException(
        'MIDI track event crossed its chunk boundary.',
      );
    }
  }

  tempoEvents.sort((left, right) {
    final tickComparison = left.tick.compareTo(right.tick);
    return tickComparison != 0
        ? tickComparison
        : left.order.compareTo(right.order);
  });
  channelEvents.sort((left, right) {
    final tickComparison = left.tick.compareTo(right.tick);
    return tickComparison != 0
        ? tickComparison
        : left.order.compareTo(right.order);
  });
  final active = <(int, int), List<_ChannelEvent>>{};
  final notes = <MidiNote>[];
  for (final event in channelEvents) {
    final key = (event.channel, event.midiNote);
    if (event.isNoteOn) {
      active.putIfAbsent(key, () => <_ChannelEvent>[]).add(event);
      continue;
    }
    final starts = active[key];
    if (starts == null || starts.isEmpty) {
      continue;
    }
    final start = starts.removeAt(0);
    notes.add(
      MidiNote(
        channel: start.channel,
        endSeconds: _tickToSeconds(event.tick, division, tempoEvents),
        endTick: event.tick,
        midiNote: start.midiNote,
        startSeconds: _tickToSeconds(start.tick, division, tempoEvents),
        startTick: start.tick,
        velocity: start.velocity,
      ),
    );
  }
  notes.sort((left, right) => left.startTick.compareTo(right.startTick));
  return notes;
}

DecodedPcmWave decodePcmWave(Uint8List bytes, {int channel = 0}) {
  final metadata = _parseWaveMetadata(bytes);
  if (channel < 0 || channel >= metadata.channelCount) {
    throw RangeError.range(channel, 0, metadata.channelCount - 1, 'channel');
  }
  final samples = _decodeWaveFrames(
    bytes,
    metadata: metadata,
    channel: channel,
    firstFrame: 0,
    frameCount: metadata.frameCount,
  );
  return DecodedPcmWave(
    sampleRateHz: metadata.sampleRateHz,
    samples: samples,
    sourceBitsPerSample: metadata.bitsPerSample,
    sourceChannelCount: metadata.channelCount,
  );
}

final class PcmWaveFileReader {
  PcmWaveFileReader(File file) : _file = file {
    if (!file.existsSync()) {
      throw ArgumentError.value(file.path, 'file', 'WAVE file does not exist.');
    }
    _handle = file.openSync();
    final prefixLength = math.min(file.lengthSync(), 1024 * 1024);
    final prefix = _handle.readSync(prefixLength);
    _metadata = _parseWaveMetadata(prefix, allowDataOutsideBytes: true);
  }

  final File _file;
  late final RandomAccessFile _handle;
  late final _WaveMetadata _metadata;

  int get bitsPerSample => _metadata.bitsPerSample;
  int get channelCount => _metadata.channelCount;
  int get frameCount => _metadata.frameCount;
  int get sampleRateHz => _metadata.sampleRateHz;
  File get sourceFile => _file;

  Float64List readSamples(int firstFrame, int frameCount, {int channel = 0}) {
    if (channel < 0 || channel >= channelCount) {
      throw RangeError.range(channel, 0, channelCount - 1, 'channel');
    }
    if (firstFrame < 0 ||
        frameCount < 0 ||
        firstFrame + frameCount > this.frameCount) {
      throw RangeError('Requested WAVE frames are outside the data chunk.');
    }
    final byteOffset =
        _metadata.dataOffset + firstFrame * _metadata.bytesPerFrame;
    final byteLength = frameCount * _metadata.bytesPerFrame;
    _handle.setPositionSync(byteOffset);
    final bytes = _handle.readSync(byteLength);
    if (bytes.length != byteLength) {
      throw const FormatException('Truncated WAVE sample data.');
    }
    final localMetadata = _metadata.copyWith(
      dataOffset: 0,
      dataLength: byteLength,
    );
    return _decodeWaveFrames(
      bytes,
      metadata: localMetadata,
      channel: channel,
      firstFrame: 0,
      frameCount: frameCount,
    );
  }

  bool channelsAreIdentical(int left, int right) {
    if (left == right) {
      return true;
    }
    if (left < 0 ||
        left >= channelCount ||
        right < 0 ||
        right >= channelCount) {
      throw RangeError('Requested WAVE channel is outside the source.');
    }
    const framesPerChunk = 65536;
    for (
      var firstFrame = 0;
      firstFrame < frameCount;
      firstFrame += framesPerChunk
    ) {
      final count = math.min(framesPerChunk, frameCount - firstFrame);
      final leftSamples = readSamples(firstFrame, count, channel: left);
      final rightSamples = readSamples(firstFrame, count, channel: right);
      for (var index = 0; index < count; index++) {
        if (leftSamples[index] != rightSamples[index]) {
          return false;
        }
      }
    }
    return true;
  }

  void close() => _handle.closeSync();
}

Float64List resampleCubic(
  Float64List input, {
  required int sourceRateHz,
  required int targetRateHz,
}) {
  if (sourceRateHz <= 0 || targetRateHz <= 0) {
    throw ArgumentError('Sample rates must be positive.');
  }
  if (input.isEmpty || sourceRateHz == targetRateHz) {
    return Float64List.fromList(input);
  }
  final outputLength = (input.length * targetRateHz / sourceRateHz).round();
  final output = Float64List(outputLength);
  final sourcePerOutput = sourceRateHz / targetRateHz;
  for (var outputIndex = 0; outputIndex < outputLength; outputIndex++) {
    final sourcePosition = outputIndex * sourcePerOutput;
    final center = sourcePosition.floor();
    final fraction = sourcePosition - center;
    final p0 = input[_clampIndex(center - 1, input.length)];
    final p1 = input[_clampIndex(center, input.length)];
    final p2 = input[_clampIndex(center + 1, input.length)];
    final p3 = input[_clampIndex(center + 2, input.length)];
    final a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3;
    final b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3;
    final c = -0.5 * p0 + 0.5 * p2;
    output[outputIndex] = ((a * fraction + b) * fraction + c) * fraction + p1;
  }
  return output;
}

int alignAttackSample(
  Float64List samples, {
  required int sampleRateHz,
  required int expectedSample,
  int searchBeforeMs = 100,
  int searchAfterMs = 150,
}) {
  if (samples.isEmpty || sampleRateHz <= 0) {
    return expectedSample.clamp(0, math.max(0, samples.length - 1));
  }
  final halfWindow = math.max(2, (sampleRateHz * 0.005).round());
  final hop = math.max(1, (sampleRateHz * 0.002).round());
  final firstCenter = math.max(
    halfWindow,
    expectedSample - (sampleRateHz * searchBeforeMs / 1000).round(),
  );
  final lastCenter = math.min(
    samples.length - halfWindow - 1,
    expectedSample + (sampleRateHz * searchAfterMs / 1000).round(),
  );
  if (firstCenter > lastCenter) {
    return expectedSample.clamp(0, samples.length - 1);
  }
  final centers = <int>[];
  final levels = <double>[];
  for (var center = firstCenter; center <= lastCenter; center += hop) {
    var energy = 0.0;
    for (
      var index = center - halfWindow;
      index < center + halfWindow;
      index++
    ) {
      energy += samples[index] * samples[index];
    }
    centers.add(center);
    levels.add(math.sqrt(energy / (halfWindow * 2)));
  }
  final sortedLevels = levels.toList()..sort();
  final noiseFloor = sortedLevels[(sortedLevels.length * 0.2).floor()];
  final peak = sortedLevels.last;
  final threshold = math.max(1e-5, math.max(noiseFloor * 6, peak * 0.15));
  for (var index = 0; index < levels.length; index++) {
    if (levels[index] >= threshold &&
        (index == 0 || levels[index - 1] < threshold)) {
      return math.min(samples.length - 1, centers[index] + halfWindow);
    }
  }
  return expectedSample.clamp(0, samples.length - 1);
}

int findAttackSample(Float64List samples, {required int sampleRateHz}) {
  if (samples.isEmpty || sampleRateHz <= 0) {
    return 0;
  }
  final halfWindow = math.max(2, (sampleRateHz * 0.005).round());
  final hop = math.max(1, (sampleRateHz * 0.002).round());
  if (samples.length <= halfWindow * 2) {
    return 0;
  }
  final centers = <int>[];
  final levels = <double>[];
  for (
    var center = halfWindow;
    center < samples.length - halfWindow;
    center += hop
  ) {
    var energy = 0.0;
    for (
      var index = center - halfWindow;
      index < center + halfWindow;
      index++
    ) {
      energy += samples[index] * samples[index];
    }
    centers.add(center);
    levels.add(math.sqrt(energy / (halfWindow * 2)));
  }
  final sortedLevels = levels.toList()..sort();
  final noiseFloor = sortedLevels[(sortedLevels.length * 0.2).floor()];
  final peak = sortedLevels.last;
  final threshold = math.max(1e-5, math.max(noiseFloor * 6, peak * 0.08));
  for (var index = 0; index < levels.length; index++) {
    if (levels[index] >= threshold &&
        (index == 0 || levels[index - 1] < threshold)) {
      return math.min(samples.length - 1, centers[index] + halfWindow);
    }
  }
  return 0;
}

Uint8List encodePcm16Wave(Float64List samples, {required int sampleRateHz}) {
  if (sampleRateHz <= 0) {
    throw ArgumentError.value(sampleRateHz, 'sampleRateHz');
  }
  final dataLength = samples.length * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRateHz, Endian.little);
  data.setUint32(28, sampleRateHz * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    final clamped = samples[index].clamp(-1.0, 32767 / 32768);
    data.setInt16(44 + index * 2, (clamped * 32768).round(), Endian.little);
  }
  return bytes;
}

Future<String> sha256File(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

double midiFrequencyHz(int midiNote) =>
    440 * math.pow(2, (midiNote - 69) / 12).toDouble();

List<MidiNote> selectRepresentativeNotes(
  List<MidiNote> notes, {
  required List<int> targetMidiNotes,
  required List<int> targetVelocities,
}) {
  if (targetMidiNotes.length != targetVelocities.length) {
    throw ArgumentError('Pitch and velocity target counts must match.');
  }
  final selected = <MidiNote>[];
  for (var index = 0; index < targetMidiNotes.length; index++) {
    final targetMidi = targetMidiNotes[index];
    final candidates =
        notes.where((note) => note.midiNote == targetMidi).toList()..sort((
          left,
          right,
        ) {
          final leftDistance = (left.velocity - targetVelocities[index]).abs();
          final rightDistance = (right.velocity - targetVelocities[index])
              .abs();
          final distanceComparison = leftDistance.compareTo(rightDistance);
          if (distanceComparison != 0) {
            return distanceComparison;
          }
          return left.startTick.compareTo(right.startTick);
        });
    if (candidates.isEmpty) {
      throw StateError('No MIDI note $targetMidi exists in the source.');
    }
    selected.add(candidates.first);
  }
  return selected;
}

double _tickToSeconds(
  int targetTick,
  int ticksPerQuarter,
  List<_TempoEvent> tempoEvents,
) {
  var seconds = 0.0;
  var previousTick = 0;
  var tempo = 500000;
  for (final event in tempoEvents) {
    if (event.tick > targetTick) {
      break;
    }
    if (event.tick > previousTick) {
      seconds +=
          (event.tick - previousTick) * tempo / ticksPerQuarter / 1000000;
      previousTick = event.tick;
    }
    tempo = event.microsecondsPerQuarter;
  }
  seconds += (targetTick - previousTick) * tempo / ticksPerQuarter / 1000000;
  return seconds;
}

_WaveMetadata _parseWaveMetadata(
  Uint8List bytes, {
  bool allowDataOutsideBytes = false,
}) {
  if (!isRiffWave(bytes)) {
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
    final chunkId = ascii.decode(bytes.sublist(offset, offset + 4));
    final chunkLength = data.getUint32(offset + 4, Endian.little);
    final payloadOffset = offset + 8;
    if (chunkId == 'fmt ') {
      if (chunkLength < 16 || payloadOffset + 16 > bytes.length) {
        throw const FormatException('Invalid fmt chunk.');
      }
      audioFormat = data.getUint16(payloadOffset, Endian.little);
      channelCount = data.getUint16(payloadOffset + 2, Endian.little);
      sampleRateHz = data.getUint32(payloadOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(payloadOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = payloadOffset;
      dataLength = chunkLength;
      break;
    }
    final nextOffset =
        payloadOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
    if (nextOffset > bytes.length) {
      if (allowDataOutsideBytes) {
        break;
      }
      throw FormatException('Truncated $chunkId chunk.');
    }
    offset = nextOffset;
  }
  if (audioFormat != 1 ||
      channelCount == null ||
      channelCount <= 0 ||
      sampleRateHz == null ||
      sampleRateHz <= 0 ||
      (bitsPerSample != 16 && bitsPerSample != 24) ||
      dataOffset == null ||
      dataLength == null) {
    throw const FormatException(
      'Only uncompressed PCM16/PCM24 WAVE with a data chunk is supported.',
    );
  }
  final resolvedBitsPerSample = bitsPerSample!;
  final bytesPerFrame = channelCount * (resolvedBitsPerSample ~/ 8);
  if (dataLength % bytesPerFrame != 0) {
    throw const FormatException('PCM data does not contain complete frames.');
  }
  if (!allowDataOutsideBytes && dataOffset + dataLength > bytes.length) {
    throw const FormatException('Truncated WAVE data chunk.');
  }
  return _WaveMetadata(
    bitsPerSample: resolvedBitsPerSample,
    channelCount: channelCount,
    dataLength: dataLength,
    dataOffset: dataOffset,
    sampleRateHz: sampleRateHz,
  );
}

Float64List _decodeWaveFrames(
  Uint8List bytes, {
  required _WaveMetadata metadata,
  required int channel,
  required int firstFrame,
  required int frameCount,
}) {
  final output = Float64List(frameCount);
  final data = ByteData.sublistView(bytes);
  final bytesPerSample = metadata.bitsPerSample ~/ 8;
  for (var outputIndex = 0; outputIndex < frameCount; outputIndex++) {
    final frame = firstFrame + outputIndex;
    final offset =
        metadata.dataOffset +
        frame * metadata.bytesPerFrame +
        channel * bytesPerSample;
    if (metadata.bitsPerSample == 16) {
      output[outputIndex] = data.getInt16(offset, Endian.little) / 32768;
    } else {
      var value =
          bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
      if (value & 0x800000 != 0) {
        value -= 0x1000000;
      }
      output[outputIndex] = value / 8388608;
    }
  }
  return output;
}

int _clampIndex(int index, int length) => index.clamp(0, length - 1);

final class _ByteReader {
  _ByteReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  String readAscii(int length) => ascii.decode(_read(length));

  int readUint8() => _read(1).single;

  int readUint16BigEndian() {
    final value = _read(2);
    return value[0] << 8 | value[1];
  }

  int readUint32BigEndian() {
    final value = _read(4);
    return value[0] << 24 | value[1] << 16 | value[2] << 8 | value[3];
  }

  int readVariableLength() {
    var value = 0;
    for (var byteCount = 0; byteCount < 4; byteCount++) {
      final byte = readUint8();
      value = (value << 7) | (byte & 0x7f);
      if (byte & 0x80 == 0) {
        return value;
      }
    }
    throw const FormatException('Invalid MIDI variable-length value.');
  }

  void skip(int length) => _read(length);

  Uint8List _read(int length) {
    if (length < 0 || offset + length > bytes.length) {
      throw const FormatException('Unexpected end of binary data.');
    }
    final value = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return value;
  }
}

final class _ChannelEvent {
  const _ChannelEvent({
    required this.channel,
    required this.isNoteOn,
    required this.midiNote,
    required this.order,
    required this.tick,
    required this.velocity,
  });

  final int channel;
  final bool isNoteOn;
  final int midiNote;
  final int order;
  final int tick;
  final int velocity;
}

final class _TempoEvent {
  const _TempoEvent({
    required this.microsecondsPerQuarter,
    required this.order,
    required this.tick,
  });

  final int microsecondsPerQuarter;
  final int order;
  final int tick;
}

final class _WaveMetadata {
  const _WaveMetadata({
    required this.bitsPerSample,
    required this.channelCount,
    required this.dataLength,
    required this.dataOffset,
    required this.sampleRateHz,
  });

  final int bitsPerSample;
  final int channelCount;
  final int dataLength;
  final int dataOffset;
  final int sampleRateHz;

  int get bytesPerFrame => channelCount * (bitsPerSample ~/ 8);
  int get frameCount => dataLength ~/ bytesPerFrame;

  _WaveMetadata copyWith({required int dataOffset, required int dataLength}) =>
      _WaveMetadata(
        bitsPerSample: bitsPerSample,
        channelCount: channelCount,
        dataLength: dataLength,
        dataOffset: dataOffset,
        sampleRateHz: sampleRateHz,
      );
}
