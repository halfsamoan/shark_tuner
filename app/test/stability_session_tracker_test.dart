import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/stability/stability_session_tracker.dart';
import 'package:toauner_app/src/tuner/live_tuner_engine.dart';
import 'package:tuner_domain/tuner_domain.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  test('requires three accepted plucks before assessing stability', () {
    final tracker = StabilitySessionTracker(stringNumber: 3);

    _addPluck(tracker, sequence: 1, base: Duration.zero);
    _addPluck(tracker, sequence: 2, base: const Duration(seconds: 3));
    expect(
      tracker.assessment.status,
      StabilityAssessmentStatus.insufficientEvidence,
    );

    _addPluck(tracker, sequence: 3, base: const Duration(seconds: 6));

    expect(tracker.completedPluckCount, 3);
    expect(tracker.assessment.status, StabilityAssessmentStatus.assessed);
    expect(tracker.assessment.evidence.trustedPluckCount, 3);
  });

  test('reports five-pluck normalized repeatability', () {
    final tracker = StabilitySessionTracker(stringNumber: 6);

    for (var index = 0; index < 5; index++) {
      _addPluck(
        tracker,
        sequence: index + 1,
        base: Duration(seconds: index * 3),
        peakRmsDb: -18 + index.toDouble(),
      );
    }

    expect(tracker.isComplete, isTrue);
    expect(tracker.assessment.evidence.repeatabilityPluckCount, 5);
    expect(
      tracker.assessment.evidence.normalizedOvershootCoefficientOfVariation,
      isNotNull,
    );
  });

  test('keeps rejected signal as insufficient evidence', () {
    final tracker = StabilitySessionTracker(stringNumber: 2);

    for (var index = 0; index < 3; index++) {
      _addPluck(
        tracker,
        sequence: index + 1,
        base: Duration(seconds: index * 3),
        clarity: .2,
      );
    }

    expect(tracker.assessment.evidence.trustedPluckCount, 0);
    expect(tracker.assessment.evidence.rejectedPluckCount, 3);
    expect(
      tracker.lastRejectionReason,
      PluckRejectionReason.insufficientValidFrames,
    );
  });
}

void _addPluck(
  StabilitySessionTracker tracker, {
  required int sequence,
  required Duration base,
  double peakRmsDb = -14,
  double clarity = .98,
}) {
  for (var milliseconds = 0; milliseconds <= 2600; milliseconds += 100) {
    final elapsed = Duration(milliseconds: milliseconds);
    final cents = milliseconds <= 100
        ? 12.0
        : .4 - (milliseconds - 100) / 10000;
    tracker.consume(
      LiveTunerState(
        status: LiveTunerStatus.listening,
        rawCents: cents,
        rawClarity: clarity,
        rmsDb: peakRmsDb - milliseconds / 1000,
        audioPosition: base + elapsed,
        onsetPosition: base,
        onsetSequence: sequence,
        freshOnset: milliseconds == 0,
      ),
    );
  }
}
