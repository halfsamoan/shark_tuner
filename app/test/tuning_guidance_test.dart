import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/tuner/tuning_guidance.dart';

void main() {
  test('sharp wound string tells the player to loosen it', () {
    final guidance = guidanceForCents(
      cents: 24,
      stringNumber: 6,
      coarseMode: false,
    );

    expect(guidance.direction, TuningDirection.lower);
    expect(guidance.headline, '음이 높아요');
    expect(guidance.instruction, contains('6번 줄 페그를 풀어 낮추세요'));
    expect(guidance.turnEstimate, '약 1/8바퀴');
  });

  test('flat plain string tells the player to tighten it', () {
    final guidance = guidanceForCents(
      cents: -48,
      stringNumber: 1,
      coarseMode: false,
    );

    expect(guidance.direction, TuningDirection.raise);
    expect(guidance.instruction, contains('1번 줄 페그를 조여 올리세요'));
    expect(guidance.turnEstimate, '약 1/4바퀴');
  });

  test('coarse mode hides a misleading turn estimate', () {
    final guidance = guidanceForCents(
      cents: 90,
      stringNumber: 4,
      coarseMode: true,
    );

    expect(guidance.coarse, isTrue);
    expect(guidance.headline, '반음 이상 높아요');
    expect(guidance.turnEstimate, isNull);
    expect(guidance.instruction, isNot(contains('바퀴')));
  });

  test('in-tune and no-signal states avoid adjustment advice', () {
    final almostInTune = guidanceForCents(
      cents: 4.9,
      stringNumber: 3,
      coarseMode: false,
    );
    expect(almostInTune.direction, TuningDirection.hold);
    expect(almostInTune.kind, GuidanceSlotKind.settling);
    expect(almostInTune.leadingSymbol, '…');
    expect(
      guidanceForCents(
        cents: null,
        stringNumber: 3,
        coarseMode: false,
      ).headline,
      '줄을 한 번 튕겨 주세요',
    );
  });

  test('signal guidance distinguishes quiet, noisy, and settling input', () {
    expect(
      guidanceForLiveInput(
        cents: null,
        rmsDb: -52,
        clarity: null,
        expectedStringNumber: 6,
      ).kind,
      GuidanceSlotKind.tooQuiet,
    );
    expect(
      guidanceForLiveInput(
        cents: null,
        rmsDb: -18,
        clarity: 0.3,
        expectedStringNumber: 6,
      ).kind,
      GuidanceSlotKind.noisy,
    );
    expect(
      guidanceForLiveInput(
        cents: null,
        rmsDb: -30,
        clarity: 0.8,
        expectedStringNumber: 6,
      ).kind,
      GuidanceSlotKind.settling,
    );
  });

  test('wrong-string guidance names both heard and expected strings', () {
    final guidance = guidanceForLiveInput(
      cents: 90,
      rmsDb: -12,
      clarity: 0.99,
      expectedStringNumber: 6,
      heardStringNumber: 3,
    );

    expect(guidance.kind, GuidanceSlotKind.wrongString);
    expect(guidance.headline, '3번 줄 소리가 들려요');
    expect(guidance.instruction, '6번 줄을 튕겨 주세요');
  });

  test('spoken tuner status names string, note, error, and action', () {
    final guidance = guidanceForCents(
      cents: 132,
      stringNumber: 6,
      coarseMode: true,
    );

    expect(
      spokenTunerStatus(
        stringNumber: 6,
        noteLabel: 'E♭2',
        cents: 132,
        guidance: guidance,
      ),
      '6번 줄, E플랫2, 132센트 높음, 낮추세요',
    );
  });
}
