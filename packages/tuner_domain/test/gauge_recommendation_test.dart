import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  group('RoundwoundUnitWeightModel', () {
    test(
      'matches twenty official calculator spot checks within three percent',
      () {
        const model = RoundwoundUnitWeightModel();
        const checks = <({double gauge, double frequency, double tension})>[
          (gauge: .018, frequency: 146.8, tension: 11.7),
          (gauge: .020, frequency: 146.8, tension: 12.7),
          (gauge: .022, frequency: 146.8, tension: 13.9),
          (gauge: .024, frequency: 146.8, tension: 16.7),
          (gauge: .026, frequency: 146.8, tension: 20.0),
          (gauge: .028, frequency: 146.8, tension: 23.2),
          (gauge: .030, frequency: 146.8, tension: 26.3),
          (gauge: .032, frequency: 146.8, tension: 30.2),
          (gauge: .034, frequency: 146.8, tension: 33.6),
          (gauge: .036, frequency: 82.4, tension: 11.4),
          (gauge: .038, frequency: 82.4, tension: 12.8),
          (gauge: .040, frequency: 82.4, tension: 14.1),
          (gauge: .042, frequency: 82.4, tension: 15.8),
          (gauge: .044, frequency: 82.4, tension: 17.0),
          (gauge: .046, frequency: 82.4, tension: 18.3),
          (gauge: .048, frequency: 82.4, tension: 20.0),
          (gauge: .050, frequency: 82.4, tension: 21.9),
          (gauge: .052, frequency: 82.4, tension: 23.2),
          (gauge: .054, frequency: 82.4, tension: 25.5),
          (gauge: .056, frequency: 82.4, tension: 27.6),
        ];

        for (final check in checks) {
          final actual = StringTensionMath.tensionLbf(
            unitWeightLbsPerInch: model.unitWeightForGauge(check.gauge),
            scaleLengthInches: 25.5,
            frequencyHz: check.frequency,
          );
          final relativeError = (actual - check.tension).abs() / check.tension;
          expect(
            relativeError,
            lessThan(.03),
            reason: 'gauge ${check.gauge} produced $actual lbf',
          );
        }
        expect(model.metadata.id, 'stringjoy-nickel-roundwound-log-fit');
        expect(model.metadata.version, 1);
        expect(model.metadata.sourceUri.host, 'tension.stringjoy.com');
      },
    );

    test('refuses to extrapolate beyond the fitted guitar range', () {
      const model = RoundwoundUnitWeightModel();

      expect(() => model.unitWeightForGauge(.017), throwsRangeError);
      expect(() => model.unitWeightForGauge(.081), throwsRangeError);
    });
  });

  group('GaugeRecommendationEngine', () {
    test('moves Drop C away from a floppy 10-46 low string', () {
      final recommendations = GaugeRecommendationEngine.recommend(
        targetTuning: BuiltInTunings.dropC,
        scale: const InstrumentScale(
          stringCount: 6,
          bassScaleInches: 25.5,
          trebleScaleInches: 25.5,
        ),
        currentTuning: BuiltInTunings.standardGuitar,
        currentGaugeSet: GaugeSetCatalog.regular10_46,
      );

      expect(recommendations, hasLength(3));
      expect(
        recommendations.first.gaugeSet.gaugesLowToHigh.first.gaugeInches,
        greaterThanOrEqualTo(.056),
      );
      expect(recommendations.first.floppyStringNumbers, isEmpty);
      expect(recommendations.first.reason, contains('현재 장력 감각'));
      expect(
        recommendations.first.strings.every(
          (result) => result.unitWeightSource != UnitWeightSource.measured,
        ),
        isTrue,
      );
    });

    test('applies the six-string Drop A low-gauge guardrail', () {
      final dropA = TuningDefinition(
        id: 'drop-a-test',
        version: 1,
        name: 'Drop A',
        strings: const [
          TuningString(stringNumber: 6, midiNote: 33, label: 'A1'),
          TuningString(stringNumber: 5, midiNote: 40, label: 'E2'),
          TuningString(stringNumber: 4, midiNote: 45, label: 'A2'),
          TuningString(stringNumber: 3, midiNote: 50, label: 'D3'),
          TuningString(stringNumber: 2, midiNote: 54, label: 'F♯3'),
          TuningString(stringNumber: 1, midiNote: 59, label: 'B3'),
        ],
      );

      final recommendations = GaugeRecommendationEngine.recommend(
        targetTuning: dropA,
        scale: const InstrumentScale(
          stringCount: 6,
          bassScaleInches: 25.5,
          trebleScaleInches: 25.5,
        ),
        currentTuning: BuiltInTunings.standardGuitar,
        currentGaugeSet: GaugeSetCatalog.regular10_46,
      );

      expect(
        recommendations.first.gaugeSet.gaugesLowToHigh.first.gaugeInches,
        greaterThanOrEqualTo(.062),
      );
      expect(recommendations.first.guardrailNotes, isNotEmpty);
    });

    test('builds a custom single-string match for the target tuning', () {
      final custom = GaugeRecommendationEngine.customMatch(
        targetTuning: BuiltInTunings.dropC,
        scale: const InstrumentScale(
          stringCount: 6,
          bassScaleInches: 25.5,
          trebleScaleInches: 25.5,
        ),
        currentTuning: BuiltInTunings.standardGuitar,
        currentGaugeSet: GaugeSetCatalog.regular10_46,
      );

      expect(custom.gaugeSet.isCustom, isTrue);
      expect(custom.gaugeSet.gaugesLowToHigh, hasLength(6));
      expect(
        custom.gaugeSet.gaugesLowToHigh.first.gaugeInches,
        greaterThanOrEqualTo(.056),
      );
      expect(custom.reason, contains('현별'));
    });

    test('accepts a user-defined current gauge set', () {
      final customCurrent = GaugeSetDefinition.electricHighToLow(
        id: 'user-current',
        displayName: '사용자 설정',
        gaugesHighToLow: const [.011, .014, .018, .030, .042, .052],
      );

      final recommendations = GaugeRecommendationEngine.recommend(
        targetTuning: BuiltInTunings.dropD,
        scale: const InstrumentScale(
          stringCount: 6,
          bassScaleInches: 25.5,
          trebleScaleInches: 25.5,
        ),
        currentTuning: BuiltInTunings.standardGuitar,
        currentGaugeSet: customCurrent,
      );

      expect(recommendations, hasLength(3));
      expect(customCurrent.isCustom, isTrue);
      expect(customCurrent.gaugesLowToHigh.first.gaugeInches, .052);
    });
  });
}
