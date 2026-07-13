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
    expect(
      guidanceForCents(
        cents: 4.9,
        stringNumber: 3,
        coarseMode: false,
      ).direction,
      TuningDirection.hold,
    );
    expect(
      guidanceForCents(
        cents: null,
        stringNumber: 3,
        coarseMode: false,
      ).headline,
      '줄을 한 번 튕겨 주세요',
    );
  });
}
