import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  test('finds a guitar-like attack after leading silence', () {
    const sampleRate = 48000;
    const attackSample = 9600;
    final samples = Float64List(sampleRate);
    for (var index = attackSample; index < samples.length; index++) {
      final elapsed = (index - attackSample) / sampleRate;
      samples[index] =
          0.5 * math.exp(-elapsed * 2) * math.sin(2 * math.pi * 110 * elapsed);
    }

    final detected = detectSignalOnsetSample(samples, sampleRateHz: sampleRate);

    expect(detected, isNotNull);
    expect((detected! - attackSample).abs(), lessThan(sampleRate * 0.01));
  });

  test('treats an already-active segment as an immediate onset', () {
    final samples = Float64List.fromList(
      List<double>.generate(1000, (index) => index.isEven ? 0.2 : -0.2),
    );

    expect(detectSignalOnsetSample(samples, sampleRateHz: 48000), 0);
  });
}
