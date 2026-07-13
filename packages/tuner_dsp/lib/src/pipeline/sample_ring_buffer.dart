import 'dart:typed_data';

/// Fixed-capacity chronological buffer for normalized audio samples.
final class SampleRingBuffer {
  SampleRingBuffer(int capacity)
    : assert(capacity > 0),
      _samples = Float64List(capacity);

  final Float64List _samples;
  var _writeIndex = 0;
  var _length = 0;

  int get capacity => _samples.length;
  int get length => _length;
  bool get isFull => _length == capacity;

  void clear() {
    _writeIndex = 0;
    _length = 0;
  }

  void write(double sample) {
    if (!sample.isFinite) {
      throw ArgumentError.value(sample, 'sample', 'Must be finite.');
    }
    _samples[_writeIndex] = sample;
    _writeIndex++;
    if (_writeIndex == capacity) {
      _writeIndex = 0;
    }
    if (_length < capacity) {
      _length++;
    }
  }

  void writeAll(Iterable<double> samples) {
    for (final sample in samples) {
      write(sample);
    }
  }

  /// Decodes whole little-endian PCM16 pairs directly into this buffer.
  ///
  /// This avoids allocating an intermediate normalized-sample list on the
  /// real-time audio path. [start] is inclusive and [end] is exclusive.
  void writePcm16Le(Uint8List bytes, {int start = 0, int? end}) {
    final checkedEnd = RangeError.checkValidRange(
      start,
      end,
      bytes.length,
      'start',
      'end',
    );
    final byteCount = checkedEnd - start;
    if (byteCount.isOdd) {
      throw ArgumentError.value(
        byteCount,
        'end - start',
        'Must contain whole PCM16 sample pairs.',
      );
    }

    var writeIndex = _writeIndex;
    var length = _length;
    for (var index = start; index < checkedEnd; index += 2) {
      final unsignedSample = bytes[index] | (bytes[index + 1] << 8);
      final signedSample = unsignedSample >= 0x8000
          ? unsignedSample - 0x10000
          : unsignedSample;
      _samples[writeIndex] = signedSample / 32768.0;
      writeIndex++;
      if (writeIndex == capacity) {
        writeIndex = 0;
      }
      if (length < capacity) {
        length++;
      }
    }
    _writeIndex = writeIndex;
    _length = length;
  }

  /// Copies the newest [count] samples in oldest-to-newest order.
  Float64List copyLatest(int count) {
    if (count < 0 || count > _length) {
      throw RangeError.range(count, 0, _length, 'count');
    }
    final result = Float64List(count);
    var start = _writeIndex - count;
    if (start < 0) {
      start += capacity;
    }
    final firstCount = count < capacity - start ? count : capacity - start;
    result.setRange(0, firstCount, _samples, start);
    if (firstCount < count) {
      result.setRange(firstCount, count, _samples);
    }
    return result;
  }
}
