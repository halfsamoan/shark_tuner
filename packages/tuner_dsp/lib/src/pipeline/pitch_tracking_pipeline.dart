import 'dart:math' as math;

import '../api/pitch_estimate.dart';
import 'estimate_stabilizer.dart';

enum OctaveCorrectionKind { none, rawHalfFrequency, rawDoubleFrequency }

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
    required this.octaveSanity,
    required this.rawEstimate,
    required this.stabilized,
  });

  final bool confidenceAccepted;
  final OctaveSanityResult? octaveSanity;
  final PitchEstimate? rawEstimate;
  final StabilizedPitchEstimate? stabilized;
}

/// Product pitch path shared by live capture and recorded-corpus reports.
///
/// Frames pass through confidence validation, target/previous-stable octave
/// sanity, median-of-five, and log-frequency EMA in that order. In-tune hold
/// remains a domain concern because it requires the selected physical string
/// and a monotonic audio timestamp.
final class PitchTrackingPipeline {
  PitchTrackingPipeline({
    required List<double> targetFrequenciesHz,
    this.octaveConfig = const OctaveSanityConfig(),
    this.stabilizerConfig = const EstimateStabilizerConfig(),
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
  final EstimateStabilizer _stabilizer;
  double? _previousStableFrequencyHz;

  PitchTrackingFrame process(PitchEstimate? rawEstimate) {
    if (!_isTrusted(rawEstimate)) {
      _stabilizer.add(null);
      return PitchTrackingFrame(
        confidenceAccepted: false,
        octaveSanity: null,
        rawEstimate: rawEstimate,
        stabilized: null,
      );
    }

    final octaveSanity = _applyOctaveSanity(rawEstimate!);
    final stabilized = _stabilizer.add(octaveSanity.estimate);
    if (stabilized != null) {
      _previousStableFrequencyHz = stabilized.frequencyHz;
    }
    return PitchTrackingFrame(
      confidenceAccepted: true,
      octaveSanity: octaveSanity,
      rawEstimate: rawEstimate,
      stabilized: stabilized,
    );
  }

  void reset() {
    _stabilizer.reset();
    _previousStableFrequencyHz = null;
  }

  bool _isTrusted(PitchEstimate? estimate) {
    return estimate != null &&
        estimate.frequencyHz.isFinite &&
        estimate.frequencyHz > 0 &&
        estimate.clarity.isFinite &&
        estimate.clarity >= stabilizerConfig.minimumClarity &&
        estimate.clarity <= 1;
  }

  OctaveSanityResult _applyOctaveSanity(PitchEstimate raw) {
    final alternatives = [
      _OctaveCandidate(raw: raw, multiplier: 0.5),
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
      if (candidateDistance <=
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
