import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  group('StringTensionMath', () {
    test('reproduces published PL010 and NW046 spot checks', () {
      expect(
        StringTensionMath.tensionLbf(
          unitWeightLbsPerInch: 0.00002215,
          scaleLengthInches: 25.5,
          frequencyHz: 329.63,
        ),
        closeTo(16.2, 0.05),
      );
      expect(
        StringTensionMath.tensionLbf(
          unitWeightLbsPerInch: 0.00038216,
          scaleLengthInches: 25.5,
          frequencyHz: 82.41,
        ),
        closeTo(17.5, 0.05),
      );
    });

    test('derives plain-steel unit weight from gauge and density', () {
      final derived = StringTensionMath.plainSteelUnitWeight(
        gaugeInches: 0.010,
      );

      expect(derived, closeTo(0.00002238, 0.00000001));
      expect((derived - 0.00002215) / 0.00002215, lessThan(0.015));
    });

    test('inverse unit-weight calculation round trips target tension', () {
      final unitWeight = StringTensionMath.unitWeightForTargetTension(
        targetTensionLbf: 18,
        scaleLengthInches: 27,
        frequencyHz: 55,
      );

      expect(
        StringTensionMath.tensionLbf(
          unitWeightLbsPerInch: unitWeight,
          scaleLengthInches: 27,
          frequencyHz: 55,
        ),
        closeTo(18, 0.000001),
      );
    });
  });

  group('InstrumentScale', () {
    test('interpolates multiscale lengths from low to high strings', () {
      const scale = InstrumentScale(
        stringCount: 3,
        bassScaleInches: 27,
        trebleScaleInches: 25.5,
      );

      expect(scale.lengthForLowToHighIndex(0), 27);
      expect(scale.lengthForLowToHighIndex(1), 26.25);
      expect(scale.lengthForLowToHighIndex(2), 25.5);
    });
  });

  group('TensionProfileCalculator', () {
    test('resolves plain derivation and measured wound unit weights', () {
      final tuning = TuningDefinition(
        id: 'two-string-check',
        version: 1,
        name: 'Two string check',
        strings: const [
          TuningString(stringNumber: 2, midiNote: 40, label: 'E2'),
          TuningString(stringNumber: 1, midiNote: 64, label: 'E4'),
        ],
      );
      const scale = InstrumentScale(
        stringCount: 2,
        bassScaleInches: 25.5,
        trebleScaleInches: 25.5,
      );
      const gauges = [
        StringGaugeSpec(
          gaugeInches: 0.046,
          construction: StringConstruction.wound,
          unitWeightLbsPerInch: 0.00038216,
          unitWeightSource: UnitWeightSource.measured,
        ),
        StringGaugeSpec(
          gaugeInches: 0.010,
          construction: StringConstruction.plain,
        ),
      ];

      final results = TensionProfileCalculator.calculate(
        tuning: tuning,
        scale: scale,
        gaugesLowToHigh: gauges,
      );

      expect(results.first.tensionLbf, closeTo(17.5, 0.1));
      expect(results.first.unitWeightSource, UnitWeightSource.measured);
      expect(results.last.tensionLbf, closeTo(16.4, 0.1));
      expect(results.last.unitWeightSource, UnitWeightSource.derived);
    });

    test('classifies floppy, comfortable, firm, and tight separately', () {
      expect(
        TensionBandClassifier.classify(
          tensionLbf: 11,
          construction: StringConstruction.plain,
        ),
        TensionBand.floppy,
      );
      expect(
        TensionBandClassifier.classify(
          tensionLbf: 18,
          construction: StringConstruction.wound,
        ),
        TensionBand.comfortable,
      );
      expect(
        TensionBandClassifier.classify(
          tensionLbf: 25,
          construction: StringConstruction.wound,
        ),
        TensionBand.firm,
      );
      expect(
        TensionBandClassifier.classify(
          tensionLbf: 29,
          construction: StringConstruction.wound,
        ),
        TensionBand.tight,
      );
    });

    test('requires wound strings to name a unit-weight source', () {
      expect(
        () => const StringGaugeSpec(
          gaugeInches: 0.046,
          construction: StringConstruction.wound,
        ).resolveUnitWeight(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
