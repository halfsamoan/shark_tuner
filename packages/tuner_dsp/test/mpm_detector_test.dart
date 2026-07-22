import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

import 'support/synthetic_pitch_corpus.dart';
import 'support/time_domain_mpm_reference.dart';

void main() {
  const sampleRate = TunerDspConfig.sampleRateHz;
  final detector = MpmDetector();

  group('MpmDetector', () {
    for (final windowSamples in [
      TunerDspConfig.standardWindowSize,
      TunerDspConfig.lowTuningWindowSize,
    ]) {
      test('enforces every S1 pure-sine gate at $windowSamples samples', () {
        final result = runPureSineCorpus(
          detector: detector,
          windowSamples: windowSamples,
        );

        expect(result.noEstimateCount, 0);
        expect(result.octaveErrorCount, 0);
        expect(result.octaveErrorRate, 0);
        expect(
          result.maximumAbsoluteErrorCents,
          lessThanOrEqualTo(result.thresholds.maximumAbsoluteErrorCents),
        );
        expect(result.passed, isTrue, reason: result.violations.join('; '));
      });
    }

    test('finds a weak fundamental beneath stronger harmonics', () {
      const frequency = 55.0;
      for (final windowSamples in [
        TunerDspConfig.standardWindowSize,
        TunerDspConfig.lowTuningWindowSize,
      ]) {
        final samples = Float64List.fromList(
          List<double>.generate(windowSamples, (index) {
            final phase = 2 * math.pi * frequency * index / sampleRate;
            return 0.35 * math.sin(phase + 0.2) +
                0.8 * math.sin(2 * phase + 0.7) +
                0.3 * math.sin(3 * phase + 1.1) +
                0.15 * math.sin(4 * phase + 0.4);
          }),
        );

        final estimate = detector.detect(samples, sampleRate: sampleRate);

        expect(estimate, isNotNull, reason: 'window=$windowSamples');
        expect(
          estimate!.centsFrom(frequency).abs(),
          lessThanOrEqualTo(2),
          reason: 'window=$windowSamples',
        );
      }
    });

    test('does not invent a pitch for silence', () {
      final estimate = detector.detect(
        Float64List(TunerDspConfig.standardWindowSize),
        sampleRate: sampleRate,
      );

      expect(estimate, isNull);
    });

    test('rejects non-finite input', () {
      final samples = generateSine(
        frequencyHz: 110,
        sampleRate: sampleRate,
        length: TunerDspConfig.standardWindowSize,
      );
      samples[100] = double.nan;

      expect(detector.detect(samples, sampleRate: sampleRate), isNull);
    });

    test('FFT path matches a direct time-domain MPM reference', () {
      const reference = TimeDomainMpmReference();
      final cases = <({double frequencyHz, int windowSamples, int waveform})>[
        (frequencyHz: 82.4069, windowSamples: 4096, waveform: 0),
        (frequencyHz: 110 * 1.009866, windowSamples: 4096, waveform: 1),
        (frequencyHz: 55, windowSamples: 8192, waveform: 2),
        (frequencyHz: 329.6276, windowSamples: 4096, waveform: 1),
      ];

      for (final testCase in cases) {
        final samples = Float64List.fromList(
          List<double>.generate(testCase.windowSamples, (index) {
            final phase =
                2 * math.pi * testCase.frequencyHz * index / sampleRate;
            return switch (testCase.waveform) {
              0 => .7 * math.sin(phase + .31),
              1 =>
                .6 * math.sin(phase + .21) +
                    .24 * math.sin(2 * phase + .77) +
                    .08 * math.sin(3 * phase + .13),
              _ =>
                .28 * math.sin(phase + .2) +
                    .72 * math.sin(2 * phase + .7) +
                    .2 * math.sin(3 * phase + 1.1),
            };
          }),
        );

        final fftEstimate = detector.detect(samples, sampleRate: sampleRate);
        final directEstimate = reference.detect(
          samples,
          sampleRate: sampleRate,
        );

        expect(fftEstimate, isNotNull);
        expect(directEstimate, isNotNull);
        expect(
          fftEstimate!.centsFrom(directEstimate!.frequencyHz).abs(),
          lessThan(.01),
          reason:
              '${testCase.frequencyHz} Hz / ${testCase.windowSamples} samples',
        );
        expect(fftEstimate.clarity, closeTo(directEstimate.clarity, 1e-7));
      }
    });
  });
}
