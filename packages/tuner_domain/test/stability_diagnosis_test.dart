import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  group('StabilityClassifier', () {
    test('returns insufficient evidence below three trusted plucks', () {
      final assessment = StabilityClassifier.assess([
        _observation(),
        _observation(),
      ]);

      expect(assessment.status, StabilityAssessmentStatus.insufficientEvidence);
      expect(assessment.evidence.trustedPluckCount, 2);
      expect(
        assessment.hypotheses.single.kind,
        StabilityHypothesisKind.insufficientEvidence,
      );
    });

    test('separates high overshoot observations from a cautious cause', () {
      final observations = [
        _observation(overshoot: 18, settleMs: 1200),
        _observation(overshoot: 20, settleMs: 1300),
        _observation(overshoot: 22, settleMs: 1250),
      ];

      final assessment = StabilityClassifier.assess(observations);

      expect(assessment.evidence.medianAttackOvershootCents, 20);
      expect(assessment.evidence.medianSettleTimeMs, 1250);
      expect(
        assessment.hypotheses.map((item) => item.kind),
        contains(StabilityHypothesisKind.possibleLightGaugeOrHeavyAttack),
      );
      expect(assessment.observations, orderedEquals(observations));
    });

    test('requires repeated step jumps before suggesting nut friction', () {
      final assessment = StabilityClassifier.assess([
        _observation(stepJump: true),
        _observation(stepJump: false),
        _observation(stepJump: true),
      ]);

      expect(assessment.evidence.stepJumpCount, 2);
      expect(
        assessment.hypotheses.map((item) => item.kind),
        contains(StabilityHypothesisKind.possibleNutFriction),
      );
    });

    test('requires consistent negative inter-pluck drift for new strings', () {
      final assessment = StabilityClassifier.assess([
        _observation(interPluckDrift: -2),
        _observation(interPluckDrift: -3),
        _observation(interPluckDrift: -2.5),
      ]);

      expect(
        assessment.hypotheses.map((item) => item.kind),
        contains(StabilityHypothesisKind.possibleNewStringStretch),
      );
    });

    test('rejects low-quality plucks instead of diagnosing noise', () {
      final assessment = StabilityClassifier.assess([
        _observation(confidence: 0.95),
        _observation(confidence: 0.7),
        _observation(validFrameRatio: 0.5),
      ]);

      expect(assessment.evidence.trustedPluckCount, 1);
      expect(assessment.evidence.rejectedPluckCount, 2);
      expect(assessment.status, StabilityAssessmentStatus.insufficientEvidence);
    });

    test(
      'reports only that no instability was observed in a stable sample',
      () {
        final assessment = StabilityClassifier.assess([
          _observation(overshoot: 5, settleMs: 500),
          _observation(overshoot: 6, settleMs: 600),
          _observation(overshoot: 4, settleMs: 550),
        ]);

        expect(
          assessment.hypotheses.single.kind,
          StabilityHypothesisKind.noInstabilityObserved,
        );
      },
    );
  });
}

StabilityPluckObservation _observation({
  double overshoot = 8,
  int settleMs = 600,
  double steadyDrift = 0.5,
  double? interPluckDrift,
  bool stepJump = false,
  double confidence = 0.95,
  double validFrameRatio = 0.9,
}) {
  return StabilityPluckObservation(
    stringNumber: 6,
    attackOvershootCents: overshoot,
    settleTime: Duration(milliseconds: settleMs),
    steadyStateDriftCentsPerSecond: steadyDrift,
    interPluckDriftCents: interPluckDrift,
    postAdjustmentStepObserved: stepJump,
    peakRmsDb: -8,
    confidence: confidence,
    validFrameRatio: validFrameRatio,
  );
}
