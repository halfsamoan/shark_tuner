import 'dart:math' as math;

enum TuningDirection { raise, lower, hold }

final class TuningGuidance {
  const TuningGuidance({
    required this.direction,
    required this.headline,
    required this.instruction,
    required this.coarse,
    this.turnEstimate,
  });

  final TuningDirection direction;
  final String headline;
  final String instruction;
  final bool coarse;
  final String? turnEstimate;

  String get arrow => switch (direction) {
    TuningDirection.raise => '▲',
    TuningDirection.lower => '▼',
    TuningDirection.hold => '✓',
  };

  String get spokenLabel => '$headline. $instruction';
}

/// Turns a cents offset into an action that does not assume a headstock shape.
///
/// Clockwise/counter-clockwise guidance belongs to the instrument-specific peg
/// map. Tighten/loosen is safe for the P0 fallback because it describes the
/// string action directly.
TuningGuidance guidanceForCents({
  required double? cents,
  required int stringNumber,
  required bool coarseMode,
  double inTuneToleranceCents = 5,
}) {
  if (cents == null || !cents.isFinite) {
    return const TuningGuidance(
      direction: TuningDirection.hold,
      headline: '줄을 한 번 튕겨 주세요',
      instruction: '소리가 멎으면 다시 한 번 튕기세요',
      coarse: false,
    );
  }
  if (cents.abs() <= inTuneToleranceCents) {
    return const TuningGuidance(
      direction: TuningDirection.hold,
      headline: '거의 맞았어요',
      instruction: '그대로 유지해 잠금을 완료하세요',
      coarse: false,
    );
  }

  final lowerPitch = cents > 0;
  final direction = lowerPitch ? TuningDirection.lower : TuningDirection.raise;
  if (coarseMode) {
    return TuningGuidance(
      direction: direction,
      headline: lowerPitch ? '반음 이상 높아요' : '반음 이상 낮아요',
      instruction: lowerPitch
          ? '$stringNumber번 줄 페그를 풀어 낮추세요'
          : '$stringNumber번 줄 페그를 조여 올리세요',
      coarse: true,
    );
  }

  final turnEstimate = _turnEstimate(
    absoluteCents: cents.abs(),
    stringNumber: stringNumber,
  );
  return TuningGuidance(
    direction: direction,
    headline: lowerPitch ? '음이 높아요' : '음이 낮아요',
    instruction: lowerPitch
        ? '$stringNumber번 줄 페그를 풀어 낮추세요 ($turnEstimate)'
        : '$stringNumber번 줄 페그를 조여 올리세요 ($turnEstimate)',
    coarse: false,
    turnEstimate: turnEstimate,
  );
}

String _turnEstimate({
  required double absoluteCents,
  required int stringNumber,
}) {
  final centsPerQuarterTurn = stringNumber <= 3 ? 45.0 : 100.0;
  final eighthTurns = (absoluteCents / centsPerQuarterTurn * 2).round().clamp(
    1,
    4,
  );
  final divisor = math.max(1, 8 ~/ _greatestCommonDivisor(eighthTurns, 8));
  final numerator = eighthTurns ~/ _greatestCommonDivisor(eighthTurns, 8);
  return '약 $numerator/$divisor바퀴';
}

int _greatestCommonDivisor(int left, int right) {
  var a = left.abs();
  var b = right.abs();
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a;
}
