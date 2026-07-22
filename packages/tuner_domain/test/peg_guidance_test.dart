import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  group('PegDirectionRule', () {
    for (final handedness in InstrumentHandedness.values) {
      for (final orientation in HeadstockOrientation.values) {
        for (final side in PegSide.values) {
          for (final winding in StringWinding.values) {
            test('$handedness $orientation $side $winding', () {
              final direction = PegDirectionRule.raisePitchDirection(
                PegConfiguration(
                  side: side,
                  handedness: handedness,
                  orientation: orientation,
                  winding: winding,
                ),
              );
              final flips = [
                handedness == InstrumentHandedness.left,
                orientation == HeadstockOrientation.reversed,
                winding == StringWinding.reversed,
              ].where((flip) => flip).length;
              final rightHandedStandard = side == PegSide.bass
                  ? PegRotationDirection.counterClockwise
                  : PegRotationDirection.clockwise;
              final expected = flips.isEven
                  ? rightHandedStandard
                  : rightHandedStandard.opposite;

              expect(direction, expected);
            });
          }
        }
      }
    }

    test('slotted rollers require a verified per-peg override', () {
      const configuration = PegConfiguration(
        side: PegSide.bass,
        mechanism: PegMechanism.slottedRoller,
      );

      expect(
        () => PegDirectionRule.raisePitchDirection(configuration),
        throwsA(isA<StateError>()),
      );
      expect(
        PegDirectionRule.raisePitchDirection(
          configuration.copyWith(
            directionOverride: PegRotationDirection.clockwise,
          ),
        ),
        PegRotationDirection.clockwise,
      );
    });
  });

  group('InstrumentPegProfile', () {
    test('maps a right-handed 3+3 headstock by physical string side', () {
      final profile = InstrumentPegProfile.split(
        stringCount: 6,
        bassSideStringCount: 3,
      );

      expect(profile.configurationForString(6).side, PegSide.bass);
      expect(profile.configurationForString(4).side, PegSide.bass);
      expect(profile.configurationForString(3).side, PegSide.treble);
      expect(profile.configurationForString(1).side, PegSide.treble);
      expect(
        profile.raisePitchDirectionForString(6),
        PegRotationDirection.counterClockwise,
      );
      expect(
        profile.raisePitchDirectionForString(1),
        PegRotationDirection.clockwise,
      );
    });

    test('maps every peg on a six-inline headstock to the bass side', () {
      final profile = InstrumentPegProfile.inline(stringCount: 6);

      for (var stringNumber = 1; stringNumber <= 6; stringNumber++) {
        expect(profile.configurationForString(stringNumber).side, PegSide.bass);
      }
    });

    test('left-handed and reverse headstocks each invert the truth table', () {
      final right = InstrumentPegProfile.inline(stringCount: 6);
      final left = InstrumentPegProfile.inline(
        stringCount: 6,
        handedness: InstrumentHandedness.left,
      );
      final reverse = InstrumentPegProfile.inline(
        stringCount: 6,
        orientation: HeadstockOrientation.reversed,
      );

      expect(
        left.raisePitchDirectionForString(6),
        right.raisePitchDirectionForString(6).opposite,
      );
      expect(
        reverse.raisePitchDirectionForString(6),
        right.raisePitchDirectionForString(6).opposite,
      );
    });

    test('supports asymmetric split layouts for seven-string guitars', () {
      final profile = InstrumentPegProfile.split(
        stringCount: 7,
        bassSideStringCount: 4,
      );

      expect(profile.configurationForString(4).side, PegSide.bass);
      expect(profile.configurationForString(3).side, PegSide.treble);
    });

    test(
      'classical rollers stay unknown until a per-peg override is saved',
      () {
        final profile = InstrumentPegProfile.classicalSplit(
          stringCount: 6,
          bassSideStringCount: 3,
        );

        expect(
          () => profile.raisePitchDirectionForString(6),
          throwsA(isA<StateError>()),
        );

        final calibrated = profile.withDirectionOverride(
          stringNumber: 6,
          raisePitchDirection: PegRotationDirection.clockwise,
        );
        expect(
          calibrated.raisePitchDirectionForString(6),
          PegRotationDirection.clockwise,
        );
        expect(
          () => calibrated.raisePitchDirectionForString(5),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('rejects string numbers and split counts outside the profile', () {
      expect(
        () =>
            InstrumentPegProfile.split(stringCount: 6, bassSideStringCount: 0),
        throwsArgumentError,
      );
      final profile = InstrumentPegProfile.inline(stringCount: 6);
      expect(() => profile.configurationForString(0), throwsRangeError);
      expect(() => profile.configurationForString(7), throwsRangeError);
    });
  });

  group('PegDirectionMonitor', () {
    test('pauses guidance after two consecutive contradictions', () {
      final monitor = PegDirectionMonitor(
        PegRotationDirection.counterClockwise,
      );

      expect(
        monitor.recordAdjustment(
          direction: PegRotationDirection.counterClockwise,
          pitchDeltaCents: -8,
        ),
        PegDirectionMonitorState.observing,
      );
      expect(
        monitor.recordAdjustment(
          direction: PegRotationDirection.counterClockwise,
          pitchDeltaCents: -7,
        ),
        PegDirectionMonitorState.flipSuggested,
      );
      expect(monitor.guidancePaused, isTrue);
    });

    test('matching movement clears a one-off contradiction', () {
      final monitor = PegDirectionMonitor(PegRotationDirection.clockwise);
      monitor.recordAdjustment(
        direction: PegRotationDirection.clockwise,
        pitchDeltaCents: -6,
      );

      expect(
        monitor.recordAdjustment(
          direction: PegRotationDirection.clockwise,
          pitchDeltaCents: 8,
        ),
        PegDirectionMonitorState.observing,
      );
      expect(monitor.consecutiveContradictions, 0);
    });

    test('accepting the suggestion persists an inverted mapping', () {
      final monitor = PegDirectionMonitor(PegRotationDirection.clockwise);
      for (var index = 0; index < 2; index++) {
        monitor.recordAdjustment(
          direction: PegRotationDirection.clockwise,
          pitchDeltaCents: -8,
        );
      }

      monitor.acceptSuggestedFlip();

      expect(
        monitor.raisePitchDirection,
        PegRotationDirection.counterClockwise,
      );
      expect(monitor.hasRuntimeOverride, isTrue);
      expect(monitor.guidancePaused, isFalse);
    });

    test('ignores pitch movement below the observation floor', () {
      final monitor = PegDirectionMonitor(PegRotationDirection.clockwise);
      for (var index = 0; index < 3; index++) {
        monitor.recordAdjustment(
          direction: PegRotationDirection.clockwise,
          pitchDeltaCents: -0.5,
        );
      }

      expect(monitor.consecutiveContradictions, 0);
      expect(monitor.guidancePaused, isFalse);
    });
  });

  group('PegRotationHint', () {
    test('uses conservative plain and wound starting heuristics', () {
      expect(
        PegRotationHint.estimate(
          centsToTarget: 50,
          construction: StringConstruction.plain,
        ).buttonTurns,
        closeTo(0.25, 0.001),
      );
      expect(
        PegRotationHint.estimate(
          centsToTarget: 100,
          construction: StringConstruction.wound,
        ).buttonTurns,
        closeTo(0.25, 0.001),
      );
    });
  });
}
