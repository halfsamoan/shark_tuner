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

  test('tracks each damp-and-pluck attack once from streaming PCM', () {
    const sampleRate = 48000;
    const firstAttack = 9600;
    const secondAttack = 38400;
    final samples = Float64List(sampleRate);
    _writePluck(samples, attackSample: firstAttack, sampleRate: sampleRate);
    _writePluck(samples, attackSample: secondAttack, sampleRate: sampleRate);
    final tracker = PluckOnsetTracker(sampleRateHz: sampleRate);
    final onsets = <int>[];

    for (var start = 0; start < samples.length; start += 733) {
      final end = math.min(start + 733, samples.length);
      onsets.addAll(tracker.addSamples(samples, start: start, end: end));
    }

    expect(onsets, hasLength(2));
    expect((onsets[0] - firstAttack).abs(), lessThan(sampleRate * 0.006));
    expect((onsets[1] - secondAttack).abs(), lessThan(sampleRate * 0.006));
  });

  test('uses the same streaming onset clock for PCM16 input', () {
    const sampleRate = 48000;
    const attackSample = 12000;
    final samples = Float64List(sampleRate ~/ 2);
    _writePluck(samples, attackSample: attackSample, sampleRate: sampleRate);
    final bytes = Uint8List(samples.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < samples.length; index++) {
      data.setInt16(index * 2, (samples[index] * 32767).round(), Endian.little);
    }
    final tracker = PluckOnsetTracker(sampleRateHz: sampleRate);
    final onsets = <int>[];

    for (var start = 0; start < bytes.length; start += 1534) {
      onsets.addAll(
        tracker.addPcm16Le(
          bytes,
          start: start,
          end: math.min(start + 1534, bytes.length),
        ),
      );
    }

    expect(onsets, hasLength(1));
    expect((onsets.single - attackSample).abs(), lessThan(sampleRate * 0.006));
  });
}

void _writePluck(
  Float64List samples, {
  required int attackSample,
  required int sampleRate,
}) {
  final end = math.min(samples.length, attackSample + sampleRate ~/ 4);
  for (var index = attackSample; index < end; index++) {
    final elapsed = (index - attackSample) / sampleRate;
    samples[index] +=
        0.45 * math.exp(-elapsed * 10) * math.sin(2 * math.pi * 110 * elapsed);
  }
}
