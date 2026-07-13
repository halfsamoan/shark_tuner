final class StabilityPluckObservation {
  StabilityPluckObservation({
    required this.stringNumber,
    required this.attackOvershootCents,
    required this.settleTime,
    required this.steadyStateDriftCentsPerSecond,
    required this.interPluckDriftCents,
    required this.postAdjustmentStepObserved,
    required this.peakRmsDb,
    required this.confidence,
    required this.validFrameRatio,
  }) {
    if (stringNumber <= 0) {
      throw ArgumentError.value(stringNumber, 'stringNumber');
    }
    for (final value in [
      attackOvershootCents,
      steadyStateDriftCentsPerSecond,
      peakRmsDb,
      if (interPluckDriftCents case final value?) value,
    ]) {
      if (!value.isFinite) {
        throw ArgumentError('Stability metrics must be finite.');
      }
    }
    if (settleTime.isNegative) {
      throw ArgumentError.value(settleTime, 'settleTime');
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(confidence, 'confidence');
    }
    if (!validFrameRatio.isFinite ||
        validFrameRatio < 0 ||
        validFrameRatio > 1) {
      throw ArgumentError.value(validFrameRatio, 'validFrameRatio');
    }
  }

  final int stringNumber;
  final double attackOvershootCents;
  final Duration settleTime;
  final double steadyStateDriftCentsPerSecond;
  final double? interPluckDriftCents;
  final bool postAdjustmentStepObserved;
  final double peakRmsDb;
  final double confidence;
  final double validFrameRatio;
}

final class StabilityClassifierConfig {
  const StabilityClassifierConfig({
    this.minimumTrustedPlucks = 3,
    this.minimumConfidence = 0.9,
    this.minimumValidFrameRatio = 0.7,
    this.highOvershootCents = 15,
    this.longSettleTime = const Duration(milliseconds: 1000),
    this.maximumStableDriftCentsPerSecond = 2,
    this.stepJumpsForNutFriction = 2,
    this.newStringFlatDriftCents = -1.5,
  }) : assert(minimumTrustedPlucks >= 3),
       assert(minimumConfidence >= 0 && minimumConfidence <= 1),
       assert(minimumValidFrameRatio >= 0 && minimumValidFrameRatio <= 1),
       assert(highOvershootCents > 0),
       assert(maximumStableDriftCentsPerSecond > 0),
       assert(stepJumpsForNutFriction > 0),
       assert(newStringFlatDriftCents < 0);

  final int minimumTrustedPlucks;
  final double minimumConfidence;
  final double minimumValidFrameRatio;
  final double highOvershootCents;
  final Duration longSettleTime;
  final double maximumStableDriftCentsPerSecond;
  final int stepJumpsForNutFriction;
  final double newStringFlatDriftCents;
}

enum StabilityAssessmentStatus { insufficientEvidence, assessed }

enum StabilityHypothesisKind {
  insufficientEvidence,
  possibleLightGaugeOrHeavyAttack,
  possibleNutFriction,
  possibleNewStringStretch,
  noInstabilityObserved,
  indeterminate,
}

final class StabilityHypothesis {
  const StabilityHypothesis({required this.kind, required this.evidenceKeys});

  final StabilityHypothesisKind kind;
  final List<String> evidenceKeys;
}

final class StabilityEvidence {
  const StabilityEvidence({
    required this.trustedPluckCount,
    required this.rejectedPluckCount,
    required this.medianAttackOvershootCents,
    required this.medianSettleTimeMs,
    required this.medianSteadyStateDriftCentsPerSecond,
    required this.medianInterPluckDriftCents,
    required this.stepJumpCount,
  });

  final int trustedPluckCount;
  final int rejectedPluckCount;
  final double? medianAttackOvershootCents;
  final double? medianSettleTimeMs;
  final double? medianSteadyStateDriftCentsPerSecond;
  final double? medianInterPluckDriftCents;
  final int stepJumpCount;
}

final class StabilityAssessment {
  StabilityAssessment({
    required this.status,
    required List<StabilityPluckObservation> observations,
    required this.evidence,
    required List<StabilityHypothesis> hypotheses,
  }) : observations = List.unmodifiable(observations),
       hypotheses = List.unmodifiable(hypotheses);

  final StabilityAssessmentStatus status;
  final List<StabilityPluckObservation> observations;
  final StabilityEvidence evidence;
  final List<StabilityHypothesis> hypotheses;
}

abstract final class StabilityClassifier {
  static StabilityAssessment assess(
    List<StabilityPluckObservation> observations, {
    StabilityClassifierConfig config = const StabilityClassifierConfig(),
  }) {
    final trusted = observations
        .where(
          (observation) =>
              observation.confidence >= config.minimumConfidence &&
              observation.validFrameRatio >= config.minimumValidFrameRatio,
        )
        .toList();
    final evidence = _summarize(
      trusted,
      rejectedCount: observations.length - trusted.length,
    );
    if (trusted.length < config.minimumTrustedPlucks) {
      return StabilityAssessment(
        status: StabilityAssessmentStatus.insufficientEvidence,
        observations: observations,
        evidence: evidence,
        hypotheses: const [
          StabilityHypothesis(
            kind: StabilityHypothesisKind.insufficientEvidence,
            evidenceKeys: ['trusted_pluck_count'],
          ),
        ],
      );
    }

    final hypotheses = <StabilityHypothesis>[];
    if (evidence.medianAttackOvershootCents! >= config.highOvershootCents &&
        evidence.medianSettleTimeMs! >= config.longSettleTime.inMilliseconds &&
        evidence.medianSteadyStateDriftCentsPerSecond!.abs() <=
            config.maximumStableDriftCentsPerSecond) {
      hypotheses.add(
        const StabilityHypothesis(
          kind: StabilityHypothesisKind.possibleLightGaugeOrHeavyAttack,
          evidenceKeys: [
            'median_attack_overshoot_cents',
            'median_settle_time_ms',
            'median_steady_state_drift_cents_per_second',
          ],
        ),
      );
    }
    if (evidence.stepJumpCount >= config.stepJumpsForNutFriction) {
      hypotheses.add(
        const StabilityHypothesis(
          kind: StabilityHypothesisKind.possibleNutFriction,
          evidenceKeys: ['step_jump_count'],
        ),
      );
    }
    final interPluckDrifts = trusted
        .map((observation) => observation.interPluckDriftCents)
        .nonNulls
        .toList();
    if (interPluckDrifts.length >= config.minimumTrustedPlucks &&
        interPluckDrifts.every((drift) => drift < 0) &&
        evidence.medianInterPluckDriftCents! <=
            config.newStringFlatDriftCents) {
      hypotheses.add(
        const StabilityHypothesis(
          kind: StabilityHypothesisKind.possibleNewStringStretch,
          evidenceKeys: ['median_inter_pluck_drift_cents'],
        ),
      );
    }
    if (hypotheses.isEmpty) {
      final looksStable =
          evidence.medianAttackOvershootCents! <= 10 &&
          evidence.medianSettleTimeMs! <= 800 &&
          evidence.medianSteadyStateDriftCentsPerSecond!.abs() <= 1 &&
          evidence.stepJumpCount == 0;
      hypotheses.add(
        StabilityHypothesis(
          kind: looksStable
              ? StabilityHypothesisKind.noInstabilityObserved
              : StabilityHypothesisKind.indeterminate,
          evidenceKeys: const [
            'median_attack_overshoot_cents',
            'median_settle_time_ms',
            'median_steady_state_drift_cents_per_second',
            'step_jump_count',
          ],
        ),
      );
    }

    return StabilityAssessment(
      status: StabilityAssessmentStatus.assessed,
      observations: observations,
      evidence: evidence,
      hypotheses: hypotheses,
    );
  }
}

StabilityEvidence _summarize(
  List<StabilityPluckObservation> observations, {
  required int rejectedCount,
}) {
  return StabilityEvidence(
    trustedPluckCount: observations.length,
    rejectedPluckCount: rejectedCount,
    medianAttackOvershootCents: _medianOrNull(
      observations.map((item) => item.attackOvershootCents),
    ),
    medianSettleTimeMs: _medianOrNull(
      observations.map((item) => item.settleTime.inMilliseconds.toDouble()),
    ),
    medianSteadyStateDriftCentsPerSecond: _medianOrNull(
      observations.map((item) => item.steadyStateDriftCentsPerSecond),
    ),
    medianInterPluckDriftCents: _medianOrNull(
      observations.map((item) => item.interPluckDriftCents).nonNulls,
    ),
    stepJumpCount: observations
        .where((item) => item.postAdjustmentStepObserved)
        .length,
  );
}

double? _medianOrNull(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) {
    return null;
  }
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
