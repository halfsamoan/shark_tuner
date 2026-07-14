import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/tuner/reference_tone_player.dart';

void main() {
  test('reference tone wave is deterministic 48 kHz mono PCM16', () {
    final first = buildReferenceToneWave(82.4068892282175);
    final second = buildReferenceToneWave(82.4068892282175);

    expect(first.bytes, orderedEquals(second.bytes));
    expect(String.fromCharCodes(first.bytes.take(4)), 'RIFF');
    expect(String.fromCharCodes(first.bytes.skip(8).take(4)), 'WAVE');
    expect(_uint16(first.bytes, 22), 1);
    expect(_uint32(first.bytes, 24), 48000);
    expect(_uint16(first.bytes, 34), 16);
    expect(first.sampleCount, greaterThanOrEqualTo(96000));
    expect(first.bytes.length, 44 + first.sampleCount * 2);
    expect(
      first.samples.map((sample) => sample.abs()).reduce(math.max),
      lessThan(16384),
    );
  });

  test('integer-cycle loop preserves target pitch within 0.01 cent', () {
    for (final frequencyHz in [43.65, 73.42, 82.41, 329.63]) {
      final wave = buildReferenceToneWave(frequencyHz);
      final cents =
          1200 * math.log(wave.actualFrequencyHz / frequencyHz) / math.ln2;

      expect(cents.abs(), lessThan(0.01), reason: '$frequencyHz Hz');
      expect(wave.cycleCount, greaterThan(0));
      expect(
        (wave.samples.first - wave.samples.last).abs(),
        lessThan(900),
        reason: '$frequencyHz Hz loop seam',
      );
    }
  });

  test('rejects frequencies outside a useful audible reference range', () {
    expect(() => buildReferenceToneWave(0), throwsArgumentError);
    expect(() => buildReferenceToneWave(double.nan), throwsArgumentError);
    expect(() => buildReferenceToneWave(16000), throwsArgumentError);
  });
}

int _uint16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _uint32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
