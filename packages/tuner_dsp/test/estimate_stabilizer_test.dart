import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  group('EstimateStabilizer', () {
    test('gates weak frames and emits only after three trusted samples', () {
      final stabilizer = EstimateStabilizer();

      expect(stabilizer.add(_estimate(110, clarity: 0.89)), isNull);
      expect(stabilizer.add(_estimate(110.1)), isNull);
      expect(stabilizer.add(_estimate(109.9)), isNull);

      final stable = stabilizer.add(_estimate(110));

      expect(stable, isNotNull);
      expect(stable!.frequencyHz, closeTo(110, 0.02));
      expect(stable.sampleCount, 3);
    });

    test('median-of-five rejects a single octave outlier', () {
      final stabilizer = EstimateStabilizer();
      for (final frequency in [110.0, 110.1, 220.0, 109.9]) {
        stabilizer.add(_estimate(frequency));
      }

      final stable = stabilizer.add(_estimate(110.05));

      expect(stable, isNotNull);
      expect(stable!.frequencyHz, closeTo(110.03, 0.08));
      expect(stable.frequencyHz, lessThan(120));
    });

    test('EMA operates in cents and settles without display chatter', () {
      final stabilizer = EstimateStabilizer();
      for (final frequency in [110.0, 110.0, 110.0]) {
        stabilizer.add(_estimate(frequency));
      }

      StabilizedPitchEstimate? stable;
      for (final frequency in [111.0, 111.0, 111.0, 111.0, 111.0]) {
        stable = stabilizer.add(_estimate(frequency));
      }

      expect(stable, isNotNull);
      expect(stable!.frequencyHz, greaterThan(110));
      expect(stable.frequencyHz, lessThan(111));
    });

    test('three consecutive missing frames reset stale history', () {
      final stabilizer = EstimateStabilizer();
      for (final frequency in [110.0, 110.0, 110.0]) {
        stabilizer.add(_estimate(frequency));
      }

      expect(stabilizer.add(null), isNull);
      expect(stabilizer.add(null), isNull);
      expect(stabilizer.add(null), isNull);
      expect(stabilizer.add(_estimate(146.83)), isNull);
      expect(stabilizer.add(_estimate(146.83)), isNull);
      expect(
        stabilizer.add(_estimate(146.83))!.frequencyHz,
        closeTo(146.83, 0.01),
      );
    });
  });
}

PitchEstimate _estimate(double frequencyHz, {double clarity = 0.95}) {
  return PitchEstimate(
    frequencyHz: frequencyHz,
    clarity: clarity,
    periodSamples: TunerDspConfig.sampleRateHz / frequencyHz,
  );
}
