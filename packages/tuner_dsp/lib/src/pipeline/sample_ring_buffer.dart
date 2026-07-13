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
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_length < capacity) {
      _length++;
    }
  }

  void writeAll(Iterable<double> samples) {
    for (final sample in samples) {
      write(sample);
    }
  }

  /// Copies the newest [count] samples in oldest-to-newest order.
  Float64List copyLatest(int count) {
    if (count < 0 || count > _length) {
      throw RangeError.range(count, 0, _length, 'count');
    }
    final result = Float64List(count);
    final start = (_writeIndex - count) % capacity;
    for (var index = 0; index < count; index++) {
      result[index] = _samples[(start + index) % capacity];
    }
    return result;
  }
}
