import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

void main() {
  group('PluckAnalyzer', () {
    test('separates attack overshoot, settle time, and steady drift', () {
      final outcome = const PluckAnalyzer().analyze(
        _syntheticPluck(
          overshootCents: 20,
          settleMs: 600,
          driftCentsPerSecond: .8,
        ),
      );

      expect(outcome.accepted, isTrue);
      final analysis = outcome.analysis!;
      expect(analysis.attackOvershootCents, closeTo(20, 1.5));
      expect(analysis.settleTime.inMilliseconds, inInclusiveRange(450, 750));
      expect(analysis.steadyStateDriftCentsPerSecond, closeTo(.8, .25));
      expect(analysis.steadyStatePitchCents, isNotNull);
      expect(analysis.confidence, greaterThan(.9));
      expect(analysis.validFrameRatio, 1);
    });

    test('rejects a pluck without enough trusted pitch frames', () {
      final frames = [
        for (var index = 0; index < 12; index++)
          PluckPitchFrame(
            elapsed: Duration(milliseconds: index * 50),
            cents: index.isEven ? null : 2,
            rmsDb: -18,
            clarity: index.isEven ? 0 : .95,
          ),
      ];

      final outcome = const PluckAnalyzer().analyze(frames);

      expect(outcome.accepted, isFalse);
      expect(
        outcome.rejectionReason,
        PluckRejectionReason.insufficientValidFrames,
      );
    });

    test(
      'does not call an ordinary pitch transition a post-adjustment step',
      () {
        final frames = _syntheticPluck(
          overshootCents: 8,
          settleMs: 500,
          driftCentsPerSecond: 0,
        );
        frames[24] = PluckPitchFrame(
          elapsed: frames[24].elapsed,
          cents: 5,
          rmsDb: frames[24].rmsDb,
          clarity: frames[24].clarity,
        );

        final ordinary = const PluckAnalyzer().analyze(frames);
        final afterAdjustment = const PluckAnalyzer().analyze(
          frames,
          detectPostAdjustmentStep: true,
        );

        expect(ordinary.analysis!.postAdjustmentStepObserved, isFalse);
        expect(afterAdjustment.analysis!.postAdjustmentStepObserved, isTrue);
      },
    );

    test(
      'handles a low-string first estimate after the nominal attack window',
      () {
        final frames =
            _syntheticPluck(
                  overshootCents: 16,
                  settleMs: 800,
                  driftCentsPerSecond: .2,
                )
                .map(
                  (frame) => frame.elapsed < const Duration(milliseconds: 170)
                      ? PluckPitchFrame(
                          elapsed: frame.elapsed,
                          cents: null,
                          rmsDb: frame.rmsDb,
                          clarity: 0,
                        )
                      : frame,
                )
                .toList();

        final outcome = const PluckAnalyzer().analyze(frames);

        expect(outcome.accepted, isTrue);
        expect(outcome.analysis!.attackOvershootCents, greaterThan(10));
      },
    );
  });
}

List<PluckPitchFrame> _syntheticPluck({
  required double overshootCents,
  required int settleMs,
  required double driftCentsPerSecond,
}) {
  const frameMs = 50;
  const durationMs = 2500;
  final frames = <PluckPitchFrame>[];
  for (var elapsedMs = 0; elapsedMs <= durationMs; elapsedMs += frameMs) {
    final progress = elapsedMs < 100
        ? 0.0
        : ((elapsedMs - 100) / math.max(1, settleMs - 100)).clamp(0.0, 1.0);
    final attackComponent = overshootCents * (1 - progress);
    final steadyElapsedSeconds = math.max(0, elapsedMs - settleMs) / 1000;
    final cents = attackComponent + driftCentsPerSecond * steadyElapsedSeconds;
    frames.add(
      PluckPitchFrame(
        elapsed: Duration(milliseconds: elapsedMs),
        cents: cents,
        rmsDb: -6 - elapsedMs / 250,
        clarity: .97,
      ),
    );
  }
  return frames;
}
