import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  group('AutomaticStringSelector', () {
    test('closest string lookup does not mutate automatic selection state', () {
      final closest = closestStringSelection(
        frequencyHz: 196,
        tuning: BuiltInTunings.standardGuitar,
      );

      expect(closest, isNotNull);
      expect(closest!.target.stringNumber, 3);
      expect(closest.cents, closeTo(0, 0.1));
    });

    test('maps concert pitch to the nearest physical string', () {
      final selector = AutomaticStringSelector();

      final selection = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
      );

      expect(selection, isNotNull);
      expect(selection!.target.stringNumber, 5);
      expect(selection.target.label, 'A2');
      expect(selection.cents, closeTo(0, 0.001));
    });

    test('uses the tuning A4 reference and song cents offset', () {
      final selector = AutomaticStringSelector();
      final shifted = TuningDefinition(
        id: 'shifted',
        version: 1,
        name: 'Shifted',
        strings: const [
          TuningString(stringNumber: 1, midiNote: 69, label: 'A4'),
        ],
        referenceA4Hz: 442,
        centsOffset: 20,
      );
      final target = shifted.strings.single.targetFrequencyHz(
        referenceA4Hz: shifted.referenceA4Hz,
        centsOffset: shifted.centsOffset,
      );

      final selection = selector.update(frequencyHz: target, tuning: shifted);

      expect(selection!.cents, closeTo(0, 0.001));
    });

    test('requires repeated evidence before switching strings', () {
      final selector = AutomaticStringSelector(
        config: const AutomaticStringSelectorConfig(
          switchConfirmationFrames: 3,
        ),
      );
      selector.update(
        frequencyHz: 82.41,
        tuning: BuiltInTunings.standardGuitar,
      );

      final first = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
        freshOnset: true,
      );
      final second = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
      );
      final third = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
      );

      expect(first!.target.stringNumber, 6);
      expect(second!.target.stringNumber, 6);
      expect(third!.target.stringNumber, 5);
    });

    test('does not switch strings on a mid-sustain harmonic jump', () {
      final selector = AutomaticStringSelector();
      selector.update(
        frequencyHz: 82.41,
        tuning: BuiltInTunings.standardGuitar,
        freshOnset: true,
      );

      final firstJump = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
      );
      final repeatedJump = selector.update(
        frequencyHz: 110,
        tuning: BuiltInTunings.standardGuitar,
      );

      expect(firstJump!.target.stringNumber, 6);
      expect(repeatedJump!.target.stringNumber, 6);
    });

    test('rejects frequencies too far from every target', () {
      final selector = AutomaticStringSelector();

      expect(
        selector.update(
          frequencyHz: 1000,
          tuning: BuiltInTunings.standardGuitar,
        ),
        isNull,
      );
    });
  });

  group('InTuneLockTracker', () {
    test('locks after one +/-2 cent hit within a second of a fresh pluck', () {
      final tracker = InTuneLockTracker();

      expect(
        tracker
            .update(cents: 18, timestamp: Duration.zero, freshOnset: true)
            .locked,
        isFalse,
      );
      expect(
        tracker
            .update(cents: -1.9, timestamp: const Duration(milliseconds: 999))
            .locked,
        isTrue,
      );
    });

    test('does not use a +/-2 cent hit after the pluck window expires', () {
      final tracker = InTuneLockTracker();

      tracker.update(cents: 18, timestamp: Duration.zero, freshOnset: true);
      expect(
        tracker
            .update(cents: 1.9, timestamp: const Duration(milliseconds: 1001))
            .locked,
        isFalse,
      );
    });

    test('locks only after remaining in tolerance for 750 ms', () {
      final tracker = InTuneLockTracker();

      expect(
        tracker.update(cents: 2.8, timestamp: Duration.zero).locked,
        isFalse,
      );
      expect(
        tracker
            .update(cents: -2.5, timestamp: const Duration(milliseconds: 749))
            .locked,
        isFalse,
      );
      expect(
        tracker
            .update(cents: 1.2, timestamp: const Duration(milliseconds: 750))
            .locked,
        isTrue,
      );
    });

    test(
      'resets the timer outside tolerance and releases beyond hysteresis',
      () {
        final tracker = InTuneLockTracker();
        tracker.update(cents: 1, timestamp: Duration.zero);
        tracker.update(cents: 4, timestamp: const Duration(milliseconds: 400));
        expect(
          tracker
              .update(cents: 1, timestamp: const Duration(milliseconds: 900))
              .locked,
          isFalse,
        );
        expect(
          tracker
              .update(cents: 1, timestamp: const Duration(milliseconds: 1650))
              .locked,
          isTrue,
        );
        expect(
          tracker
              .update(cents: 4, timestamp: const Duration(milliseconds: 1700))
              .locked,
          isTrue,
        );
        expect(
          tracker
              .update(cents: 6, timestamp: const Duration(milliseconds: 1800))
              .locked,
          isFalse,
        );
      },
    );

    test('supports beginner and pro tolerances through configuration', () {
      final beginner = InTuneLockTracker(
        config: const InTuneLockConfig(toleranceCents: 5),
      );
      final pro = InTuneLockTracker(
        config: const InTuneLockConfig(
          toleranceCents: 1.5,
          releaseToleranceCents: 2.5,
        ),
      );

      expect(
        beginner.update(cents: 4, timestamp: Duration.zero).withinTolerance,
        isTrue,
      );
      expect(
        pro.update(cents: 4, timestamp: Duration.zero).withinTolerance,
        isFalse,
      );
    });

    test('keeps an established lock through one low-quality frame', () {
      final tracker = InTuneLockTracker();
      tracker.update(cents: 1, timestamp: Duration.zero);
      tracker.update(cents: 1, timestamp: const Duration(milliseconds: 750));

      expect(
        tracker
            .markMissing(timestamp: const Duration(milliseconds: 800))
            .locked,
        isTrue,
      );
      expect(
        tracker
            .update(cents: 4, timestamp: const Duration(milliseconds: 850))
            .locked,
        isTrue,
      );
    });

    test('releases after three consecutive low-quality frames', () {
      final tracker = InTuneLockTracker();
      tracker.update(cents: 1, timestamp: Duration.zero);
      tracker.update(cents: 1, timestamp: const Duration(milliseconds: 750));

      tracker.markMissing(timestamp: const Duration(milliseconds: 800));
      tracker.markMissing(timestamp: const Duration(milliseconds: 850));
      expect(
        tracker
            .markMissing(timestamp: const Duration(milliseconds: 900))
            .locked,
        isFalse,
      );
    });
  });

  group('TuneUpProgressTracker', () {
    test('counts each physical string once and freezes completion time', () {
      final tracker = TuneUpProgressTracker(
        expectedStringNumbers: const [6, 5, 4],
      );

      tracker.recordLock(stringNumber: 6, elapsed: const Duration(seconds: 10));
      tracker.recordLock(stringNumber: 6, elapsed: const Duration(seconds: 15));
      tracker.recordLock(stringNumber: 5, elapsed: const Duration(seconds: 30));
      final complete = tracker.recordLock(
        stringNumber: 4,
        elapsed: const Duration(seconds: 44),
      );
      final afterCompletion = tracker.recordLock(
        stringNumber: 4,
        elapsed: const Duration(seconds: 60),
      );

      expect(complete.lockedStringNumbers, {4, 5, 6});
      expect(complete.isComplete, isTrue);
      expect(complete.elapsed, const Duration(seconds: 44));
      expect(afterCompletion.elapsed, const Duration(seconds: 44));
    });

    test('rejects unknown strings and non-monotonic timestamps', () {
      final tracker = TuneUpProgressTracker(
        expectedStringNumbers: const [2, 1],
      );
      tracker.recordLock(stringNumber: 2, elapsed: const Duration(seconds: 5));

      expect(
        () => tracker.recordLock(
          stringNumber: 3,
          elapsed: const Duration(seconds: 6),
        ),
        throwsArgumentError,
      );
      expect(
        () => tracker.recordLock(
          stringNumber: 1,
          elapsed: const Duration(seconds: 4),
        ),
        throwsArgumentError,
      );
    });
  });
}
