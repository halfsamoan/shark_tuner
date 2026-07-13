import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  const sampleRate = TunerDspConfig.sampleRateHz;
  const detector = MpmDetector();

  group('MpmDetector', () {
    test(
      'meets the synthetic sine-wave p95 gate across the supported range',
      () {
        final absoluteErrors = <double>[];
        const baseFrequencies = <double>[
          43.65,
          55,
          82.41,
          110,
          329.63,
          440,
          880,
          1318.51,
        ];
        const offsets = <double>[-49, -17, -3, 0, 3, 17, 49];

        for (final baseFrequency in baseFrequencies) {
          for (final offset in offsets) {
            final frequency = baseFrequency * math.pow(2, offset / 1200);
            if (frequency < TunerDspConfig.minimumFrequencyHz ||
                frequency > TunerDspConfig.maximumFrequencyHz) {
              continue;
            }
            final samples = _sine(
              frequencyHz: frequency,
              sampleRate: sampleRate,
              length: TunerDspConfig.lowTuningWindowSize,
            );

            final estimate = detector.detect(samples, sampleRate: sampleRate);

            expect(estimate, isNotNull, reason: 'No estimate at $frequency Hz');
            absoluteErrors.add(estimate!.centsFrom(frequency).abs());
          }
        }

        absoluteErrors.sort();
        final median = _percentile(absoluteErrors, 0.5);
        final p95 = _percentile(absoluteErrors, 0.95);
        expect(median, lessThanOrEqualTo(0.5));
        expect(p95, lessThanOrEqualTo(1.0));
      },
    );

    test('finds a weak fundamental beneath stronger harmonics', () {
      const frequency = 55.0;
      final samples = Float64List.fromList(
        List<double>.generate(TunerDspConfig.lowTuningWindowSize, (index) {
          final phase = 2 * math.pi * frequency * index / sampleRate;
          return 0.35 * math.sin(phase + 0.2) +
              0.8 * math.sin(2 * phase + 0.7) +
              0.3 * math.sin(3 * phase + 1.1) +
              0.15 * math.sin(4 * phase + 0.4);
        }),
      );

      final estimate = detector.detect(samples, sampleRate: sampleRate);

      expect(estimate, isNotNull);
      expect(estimate!.centsFrom(frequency).abs(), lessThanOrEqualTo(2));
    });

    test('does not invent a pitch for silence', () {
      final estimate = detector.detect(
        Float64List(TunerDspConfig.standardWindowSize),
        sampleRate: sampleRate,
      );

      expect(estimate, isNull);
    });

    test('rejects non-finite input', () {
      final samples = _sine(
        frequencyHz: 110,
        sampleRate: sampleRate,
        length: TunerDspConfig.standardWindowSize,
      );
      samples[100] = double.nan;

      expect(detector.detect(samples, sampleRate: sampleRate), isNull);
    });
  });
}

Float64List _sine({
  required double frequencyHz,
  required double sampleRate,
  required int length,
}) {
  const phaseOffset = 0.37;
  return Float64List.fromList(
    List<double>.generate(
      length,
      (index) => math.sin(
        2 * math.pi * frequencyHz * index / sampleRate + phaseOffset,
      ),
    ),
  );
}

double _percentile(List<double> sortedValues, double percentile) {
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index];
}
