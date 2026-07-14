import 'dart:math' as math;

enum TuningDirection { raise, lower, hold }

enum GuidanceSlotKind {
  pluckPrompt,
  direction,
  wrongString,
  tooQuiet,
  noisy,
  settling,
}

final class TuningGuidance {
  const TuningGuidance({
    required this.direction,
    required this.headline,
    required this.instruction,
    required this.coarse,
    this.turnEstimate,
    this.kind = GuidanceSlotKind.direction,
  });

  final TuningDirection direction;
  final String headline;
  final String instruction;
  final bool coarse;
  final String? turnEstimate;
  final GuidanceSlotKind kind;

  String get leadingSymbol => switch (kind) {
    GuidanceSlotKind.pluckPrompt => '●',
    GuidanceSlotKind.wrongString => '!',
    GuidanceSlotKind.tooQuiet => '↟',
    GuidanceSlotKind.noisy => '≈',
    GuidanceSlotKind.settling => '…',
    GuidanceSlotKind.direction => switch (direction) {
      TuningDirection.raise => '▲',
      TuningDirection.lower => '▼',
      TuningDirection.hold => '✓',
    },
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
      kind: GuidanceSlotKind.pluckPrompt,
    );
  }
  if (cents.abs() <= inTuneToleranceCents) {
    return const TuningGuidance(
      direction: TuningDirection.hold,
      headline: '거의 맞았어요',
      instruction: '그대로 유지해 잠금을 완료하세요',
      coarse: false,
      kind: GuidanceSlotKind.settling,
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

TuningGuidance guidanceForLiveInput({
  required double? cents,
  required double? rmsDb,
  required double? clarity,
  required int expectedStringNumber,
  int? heardStringNumber,
  bool coarseMode = false,
}) {
  if (heardStringNumber != null && heardStringNumber != expectedStringNumber) {
    return TuningGuidance(
      direction: TuningDirection.hold,
      headline: '$heardStringNumber번 줄 소리가 들려요',
      instruction: '$expectedStringNumber번 줄을 튕겨 주세요',
      coarse: false,
      kind: GuidanceSlotKind.wrongString,
    );
  }
  if (cents != null && cents.isFinite) {
    return guidanceForCents(
      cents: cents,
      stringNumber: expectedStringNumber,
      coarseMode: coarseMode,
    );
  }
  if (rmsDb == null || !rmsDb.isFinite || rmsDb <= -60) {
    return TuningGuidance(
      direction: TuningDirection.hold,
      headline: '줄을 한 번 튕겨 주세요',
      instruction: '$expectedStringNumber번 줄을 튕기고 울리게 두세요',
      coarse: false,
      kind: GuidanceSlotKind.pluckPrompt,
    );
  }
  if (rmsDb < -46) {
    return TuningGuidance(
      direction: TuningDirection.hold,
      headline: '소리가 너무 작아요',
      instruction: '$expectedStringNumber번 줄을 조금 더 세게 튕겨 주세요',
      coarse: false,
      kind: GuidanceSlotKind.tooQuiet,
    );
  }
  if (rmsDb > -30 && clarity != null && clarity < 0.6) {
    return const TuningGuidance(
      direction: TuningDirection.hold,
      headline: '주변 소리가 함께 들려요',
      instruction: '다른 줄을 뮤트하고 한 줄만 울려 주세요',
      coarse: false,
      kind: GuidanceSlotKind.noisy,
    );
  }
  return const TuningGuidance(
    direction: TuningDirection.hold,
    headline: '음을 잡는 중이에요',
    instruction: '한 줄만 그대로 울리게 두세요',
    coarse: false,
    kind: GuidanceSlotKind.settling,
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

String spokenTunerStatus({
  required int stringNumber,
  required String noteLabel,
  required double? cents,
  required TuningGuidance guidance,
}) {
  final spokenNote = noteLabel.replaceAll('♭', '플랫').replaceAll('♯', '샵');
  final prefix = '$stringNumber번 줄, $spokenNote';
  if (guidance.headline.contains('완료')) {
    return '$prefix, 완료';
  }
  if (guidance.kind == GuidanceSlotKind.wrongString ||
      cents == null ||
      !cents.isFinite) {
    return '$prefix, ${guidance.spokenLabel}';
  }
  final absoluteCents = cents.abs().round();
  if (guidance.direction == TuningDirection.lower) {
    return '$prefix, $absoluteCents센트 높음, 낮추세요';
  }
  if (guidance.direction == TuningDirection.raise) {
    return '$prefix, $absoluteCents센트 낮음, 올리세요';
  }
  return '$prefix, $absoluteCents센트 이내, 유지하세요';
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
