import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  group('SampleRingBuffer', () {
    test('returns the newest samples in chronological order', () {
      final buffer = SampleRingBuffer(4)..writeAll([1, 2, 3]);

      expect(buffer.copyLatest(2), [2, 3]);
      expect(buffer.length, 3);
      expect(buffer.isFull, isFalse);
    });

    test('overwrites the oldest samples after wrapping', () {
      final buffer = SampleRingBuffer(4)..writeAll([1, 2, 3, 4, 5, 6]);

      expect(buffer.copyLatest(4), [3, 4, 5, 6]);
      expect(buffer.length, 4);
      expect(buffer.isFull, isTrue);
    });

    test(
      'bulk decodes signed little-endian PCM16 without an intermediate list',
      () {
        final bytes = Uint8List.fromList([
          0x00,
          0x80,
          0x00,
          0xC0,
          0x00,
          0x00,
          0x00,
          0x40,
          0xFF,
          0x7F,
        ]);
        final buffer = SampleRingBuffer(4);

        buffer.writePcm16Le(bytes, start: 2, end: bytes.length);

        expect(buffer.copyLatest(4), [-0.5, 0, 0.5, 32767 / 32768]);
        expect(buffer.isFull, isTrue);
      },
    );

    test('bulk PCM16 writes require whole sample pairs', () {
      final buffer = SampleRingBuffer(4);

      expect(() => buffer.writePcm16Le(Uint8List(3)), throwsArgumentError);
    });

    test('clear removes logical contents', () {
      final buffer = SampleRingBuffer(2)..writeAll([1, 2]);

      buffer.clear();

      expect(buffer.length, 0);
      expect(buffer.copyLatest(0), isEmpty);
    });

    test('rejects requests larger than available contents', () {
      final buffer = SampleRingBuffer(4)..write(1);

      expect(() => buffer.copyLatest(2), throwsRangeError);
    });
  });
}
