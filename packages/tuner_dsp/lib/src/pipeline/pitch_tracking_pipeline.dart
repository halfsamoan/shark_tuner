import 'dart:math' as math;

import '../api/pitch_estimate.dart';
import 'estimate_stabilizer.dart';

enum OctaveCorrectionKind {
  none,
  rawHalfFrequency,
  rawDoubleFrequency,
  rawTripleFrequency,
}

enum OctaveSanityAnchor { none, target, previousStable }

final class OctaveSanityConfig {
  const OctaveSanityConfig({
    this.maximumCorrectedTargetDistanceCents = 75,
    this.minimumTargetImprovementCents = 100,
    this.maximumCorrectedPreviousDistanceCents = 75,
    this.minimumPreviousImprovementCents = 600,
  }) : assert(maximumCorrectedTargetDistanceCents >= 0),
       assert(minimumTargetImprovementCents > 0),
       assert(maximumCorrectedPreviousDistanceCents >= 0),
       assert(minimumPreviousImprovementCents > 0);

  final double maximumCorrectedTargetDistanceCents;
  final double minimumTargetImprovementCents;
  final double maximumCorrectedPreviousDistanceCents;
  final double minimumPreviousImprovementCents;
}

final class TargetAssistedConfidenceConfig {
  const TargetAssistedConfidenceConfig({
    this.minimumClarity = 0.81,
    this.maximumTargetDistanceCents = 75,
  }) : assert(minimumClarity >= 0 && minimumClarity <= 1),
       assert(maximumTargetDistanceCents >= 0);

  /// A detector estimate below the normal 0.9 gate is only retained when it
  /// is already close to one of the known physical-string targets.
  final double minimumClarity;
  final double maximumTargetDistanceCents;
}

final class OctaveSanityResult {
  const OctaveSanityResult({
    required this.anchor,
    required this.estimate,
    required this.frequencyMultiplier,
    required this.kind,
  });

  final OctaveSanityAnchor anchor;
  final PitchEstimate estimate;
  final double frequencyMultiplier;
  final OctaveCorrectionKind kind;

  bool get corrected => kind != OctaveCorrectionKind.none;
}

final class PitchTrackingFrame {
  const PitchTrackingFrame({
    required this.confidenceAccepted,
    required this.targetAssistedConfidence,
    required this.octaveSanity,
    required this.rawEstimate,
    required this.stabilized,
  });

  final bool confidenceAccepted;
  final bool targetAssistedConfidence;
  final OctaveSanityResult? octaveSanity;
  final PitchEstimate? rawEstimate;
  final StabilizedPitchEstimate? stabilized;
}

/// Product pitch path shared by live capture and recorded-corpus reports.
///
/// Frames pass through confidence validation, conservative target-assisted
/// recovery, target/previous-stable octave sanity, median-of-five, and a
/// log-frequency EMA in that order. In-tune hold remains a domain concern
/// because it requires the selected physical string and a monotonic timestamp.
final class PitchTrackingPipeline {
  PitchTrackingPipeline({
    required List<double> targetFrequenciesHz,
    this.octaveConfig = const OctaveSanityConfig(),
    this.stabilizerConfig = const EstimateStabilizerConfig(),
    this.targetAssistedConfidenceConfig =
        const TargetAssistedConfidenceConfig(),
  }) : targetFrequenciesHz = List.unmodifiable(targetFrequenciesHz),
       _stabilizer = EstimateStabilizer(config: stabilizerConfig) {
    if (targetFrequenciesHz.any(
      (frequency) => !frequency.isFinite || frequency <= 0,
    )) {
      throw ArgumentError.value(
        targetFrequenciesHz,
        'targetFrequenciesHz',
        'Targets must be finite and greater than zero.',
      );
    }
  }

  final List<double> targetFrequenciesHz;
  final OctaveSanityConfig octaveConfig;
  final EstimateStabilizerConfig stabilizerConfig;
  final TargetAssistedConfidenceConfig targetAssistedConfidenceConfig;
  final EstimateStabilizer _stabilizer;
  double? _previousStableFrequencyHz;
  int _missingTrustedFrames = 0;

  PitchTrackingFrame process(PitchEstimate? rawEstimate) {
    final acceptedClarityFloor = _acceptedClarityFloor(rawEstimate);
    if (acceptedClarityFloor == null) {
      _missingTrustedFrames++;
      _stabilizer.add(null);
      if (_missingTrustedFrames >= stabilizerConfig.missingFramesBeforeReset) {
        _previousStableFrequencyHz = null;
      }
      return PitchTrackingFrame(
        confidenceAccepted: false,
        targetAssistedConfidence: false,
        octaveSanity: null,
        rawEstimate: rawEstimate,
        stabilized: null,
      );
    }

    _missingTrustedFrames = 0;
    final octaveSanity = _applyOctaveSanity(rawEstimate!);
    final stabilized = _stabilizer.add(
      octaveSanity.estimate,
      minimumClarity: acceptedClarityFloor,
    );
    if (stabilized != null) {
      _previousStableFrequencyHz = stabilized.frequencyHz;
    }
    return PitchTrackingFrame(
      confidenceAccepted: true,
      targetAssistedConfidence:
          rawEstimate.clarity < stabilizerConfig.minimumClarity,
      octaveSanity: octaveSanity,
      rawEstimate: rawEstimate,
      stabilized: stabilized,
    );
  }

  void reset() {
    _stabilizer.reset();
    _previousStableFrequencyHz = null;
    _missingTrustedFrames = 0;
  }

  double? _acceptedClarityFloor(PitchEstimate? estimate) {
    if (estimate == null ||
        !estimate.frequencyHz.isFinite ||
        estimate.frequencyHz <= 0 ||
        !estimate.clarity.isFinite ||
        estimate.clarity > 1) {
      return null;
    }
    if (estimate.clarity >= stabilizerConfig.minimumClarity) {
      return stabilizerConfig.minimumClarity;
    }
    if (targetFrequenciesHz.isEmpty ||
        estimate.clarity < targetAssistedConfidenceConfig.minimumClarity ||
        _distanceToNearest(estimate.frequencyHz, targetFrequenciesHz) >
            targetAssistedConfidenceConfig.maximumTargetDistanceCents) {
      return null;
    }
    return targetAssistedConfidenceConfig.minimumClarity;
  }

  OctaveSanityResult _applyOctaveSanity(PitchEstimate raw) {
    final alternatives = [
      _OctaveCandidate(raw: raw, multiplier: 0.5),
      _OctaveCandidate(raw: raw, multiplier: 1 / 3),
      _OctaveCandidate(raw: raw, multiplier: 2),
    ];
    final rawTargetDistance = _distanceToNearest(
      raw.frequencyHz,
      targetFrequenciesHz,
    );
    final previous = _previousStableFrequencyHz;
    final rawPreviousDistance = previous == null
        ? double.infinity
        : _absoluteCents(raw.frequencyHz, previous);

    _OctaveCandidate? bestTarget;
    if (targetFrequenciesHz.isNotEmpty) {
      alternatives.sort((left, right) {
        final targetComparison = _distanceToNearest(
          left.frequencyHz,
          targetFrequenciesHz,
        ).compareTo(_distanceToNearest(right.frequencyHz, targetFrequenciesHz));
        if (targetComparison != 0 || previous == null) {
          return targetComparison;
        }
        return _absoluteCents(
          left.frequencyHz,
          previous,
        ).compareTo(_absoluteCents(right.frequencyHz, previous));
      });
      final candidate = alternatives.first;
      final candidateDistance = _distanceToNearest(
        candidate.frequencyHz,
        targetFrequenciesHz,
      );
      // A target alone cannot distinguish a detector f/2 error from a string
      // that is physically tuned one octave too low. Cold-start target snaps
      // therefore only fold a higher harmonic down when it is materially
      // closer than the raw candidate. Upward correction needs a recent
      // previous-stable anchor and is evaluated below.
      if (candidate.multiplier < 1 &&
          candidateDistance <=
              octaveConfig.maximumCorrectedTargetDistanceCents &&
          rawTargetDistance - candidateDistance >=
              octaveConfig.minimumTargetImprovementCents) {
        bestTarget = candidate;
      }
    }
    if (bestTarget != null) {
      return _resultFor(bestTarget, OctaveSanityAnchor.target);
    }

    if (previous != null) {
      alternatives.sort(
        (left, right) => _absoluteCents(
          left.frequencyHz,
          previous,
        ).compareTo(_absoluteCents(right.frequencyHz, previous)),
      );
      final candidate = alternatives.first;
      final candidateDistance = _absoluteCents(candidate.frequencyHz, previous);
      if (candidateDistance <=
              octaveConfig.maximumCorrectedPreviousDistanceCents &&
          rawPreviousDistance - candidateDistance >=
              octaveConfig.minimumPreviousImprovementCents) {
        return _resultFor(candidate, OctaveSanityAnchor.previousStable);
      }
    }

    return OctaveSanityResult(
      anchor: OctaveSanityAnchor.none,
      estimate: raw,
      frequencyMultiplier: 1,
      kind: OctaveCorrectionKind.none,
    );
  }

  OctaveSanityResult _resultFor(
    _OctaveCandidate candidate,
    OctaveSanityAnchor anchor,
  ) {
    return OctaveSanityResult(
      anchor: anchor,
      estimate: candidate.estimate,
      frequencyMultiplier: candidate.multiplier,
      kind: candidate.multiplier > 1
          ? OctaveCorrectionKind.rawHalfFrequency
          : candidate.multiplier < .4
          ? OctaveCorrectionKind.rawTripleFrequency
          : OctaveCorrectionKind.rawDoubleFrequency,
    );
  }
}

final class _OctaveCandidate {
  _OctaveCandidate({required PitchEstimate raw, required this.multiplier})
    : estimate = PitchEstimate(
        frequencyHz: raw.frequencyHz * multiplier,
        clarity: raw.clarity,
        periodSamples: raw.periodSamples / multiplier,
      );

  final PitchEstimate estimate;
  final double multiplier;

  double get frequencyHz => estimate.frequencyHz;
}

double _distanceToNearest(double frequencyHz, List<double> anchors) {
  if (anchors.isEmpty) {
    return double.infinity;
  }
  var distance = double.infinity;
  for (final anchor in anchors) {
    distance = math.min(distance, _absoluteCents(frequencyHz, anchor));
  }
  return distance;
}

double _absoluteCents(double frequencyHz, double referenceHz) {
  return (1200 * math.log(frequencyHz / referenceHz) / math.ln2).abs();
}
