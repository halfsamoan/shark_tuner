import 'dart:math' as math;

final class PluckPitchFrame {
  PluckPitchFrame({
    required this.elapsed,
    required this.cents,
    required this.rmsDb,
    required this.clarity,
  }) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed');
    }
    if (cents case final value? when !value.isFinite) {
      throw ArgumentError.value(value, 'cents');
    }
    if (!rmsDb.isFinite) {
      throw ArgumentError.value(rmsDb, 'rmsDb');
    }
    if (!clarity.isFinite || clarity < 0 || clarity > 1) {
      throw ArgumentError.value(clarity, 'clarity');
    }
  }

  final Duration elapsed;
  final double? cents;
  final double rmsDb;
  final double clarity;
}

final class PluckAnalyzerConfig {
  const PluckAnalyzerConfig({
    this.minimumClarity = .9,
    this.minimumValidFrames = 12,
    this.minimumValidFrameRatio = .7,
    this.attackStart = const Duration(milliseconds: 50),
    this.attackEnd = const Duration(milliseconds: 150),
    this.fallbackAttackWindow = const Duration(milliseconds: 150),
    this.steadyReferenceStartFraction = .55,
    this.minimumSteadyReferenceStart = const Duration(milliseconds: 1000),
    this.settleToleranceCents = 3,
    this.settleHold = const Duration(milliseconds: 300),
    this.signalFloorBelowPeakDb = 30,
    this.stepJumpCents = 3,
    this.maximumAdjacentFrameGap = const Duration(milliseconds: 200),
  }) : assert(minimumClarity >= 0 && minimumClarity <= 1),
       assert(minimumValidFrames > 0),
       assert(minimumValidFrameRatio > 0 && minimumValidFrameRatio <= 1),
       assert(
         steadyReferenceStartFraction > 0 && steadyReferenceStartFraction < 1,
       ),
       assert(settleToleranceCents > 0),
       assert(signalFloorBelowPeakDb > 0),
       assert(stepJumpCents > 0);

  final double minimumClarity;
  final int minimumValidFrames;
  final double minimumValidFrameRatio;
  final Duration attackStart;
  final Duration attackEnd;
  final Duration fallbackAttackWindow;
  final double steadyReferenceStartFraction;
  final Duration minimumSteadyReferenceStart;
  final double settleToleranceCents;
  final Duration settleHold;
  final double signalFloorBelowPeakDb;
  final double stepJumpCents;
  final Duration maximumAdjacentFrameGap;
}

enum PluckRejectionReason {
  emptyTrack,
  nonMonotonicFrames,
  insufficientValidFrames,
  noSteadyReference,
  didNotSettle,
}

final class PluckAnalysis {
  const PluckAnalysis({
    required this.attackOvershootCents,
    required this.settleTime,
    required this.steadyStatePitchCents,
    required this.steadyStateDriftCentsPerSecond,
    required this.postAdjustmentStepObserved,
    required this.peakRmsDb,
    required this.confidence,
    required this.validFrameRatio,
    required this.validFrameCount,
  });

  final double attackOvershootCents;
  final Duration settleTime;
  final double steadyStatePitchCents;
  final double steadyStateDriftCentsPerSecond;
  final bool postAdjustmentStepObserved;
  final double peakRmsDb;
  final double confidence;
  final double validFrameRatio;
  final int validFrameCount;
}

final class PluckAnalysisOutcome {
  const PluckAnalysisOutcome.accepted(this.analysis) : rejectionReason = null;

  const PluckAnalysisOutcome.rejected(this.rejectionReason) : analysis = null;

  final PluckAnalysis? analysis;
  final PluckRejectionReason? rejectionReason;

  bool get accepted => analysis != null;
}

/// Extracts observable pitch behavior from one onset-aligned raw pitch track.
///
/// This class deliberately does not diagnose strings or hardware. It reports
/// the attack, settling, and steady-state measurements consumed later by the
/// domain classifier. A step jump is only evaluated when the caller explicitly
/// marks the track as post-adjustment evidence.
final class PluckAnalyzer {
  const PluckAnalyzer({this.config = const PluckAnalyzerConfig()});

  final PluckAnalyzerConfig config;

  PluckAnalysisOutcome analyze(
    List<PluckPitchFrame> frames, {
    bool detectPostAdjustmentStep = false,
  }) {
    if (frames.isEmpty) {
      return const PluckAnalysisOutcome.rejected(
        PluckRejectionReason.emptyTrack,
      );
    }
    for (var index = 1; index < frames.length; index++) {
      if (frames[index].elapsed <= frames[index - 1].elapsed) {
        return const PluckAnalysisOutcome.rejected(
          PluckRejectionReason.nonMonotonicFrames,
        );
      }
    }

    final peakRmsDb = frames.map((frame) => frame.rmsDb).reduce(math.max);
    final signalFloorDb = peakRmsDb - config.signalFloorBelowPeakDb;
    final sounding = frames
        .where((frame) => frame.rmsDb >= signalFloorDb)
        .toList(growable: false);
    final trusted = sounding.where(_isTrusted).toList(growable: false);
    final validFrameRatio = sounding.isEmpty
        ? 0.0
        : trusted.length / sounding.length;
    if (trusted.length < config.minimumValidFrames ||
        validFrameRatio < config.minimumValidFrameRatio) {
      return const PluckAnalysisOutcome.rejected(
        PluckRejectionReason.insufficientValidFrames,
      );
    }

    final trackDuration = frames.last.elapsed;
    final fractionalSteadyStart = Duration(
      microseconds:
          (trackDuration.inMicroseconds * config.steadyReferenceStartFraction)
              .round(),
    );
    final steadyReferenceStart =
        fractionalSteadyStart > config.minimumSteadyReferenceStart
        ? fractionalSteadyStart
        : config.minimumSteadyReferenceStart;
    final lateFrames = trusted
        .where((frame) => frame.elapsed >= steadyReferenceStart)
        .toList(growable: false);
    if (lateFrames.length < 3) {
      return const PluckAnalysisOutcome.rejected(
        PluckRejectionReason.noSteadyReference,
      );
    }
    final steadyReference = _median(
      lateFrames.map((frame) => frame.cents!).toList(),
    );

    final settleFrame = _findSettleFrame(trusted, steadyReference);
    if (settleFrame == null) {
      return const PluckAnalysisOutcome.rejected(
        PluckRejectionReason.didNotSettle,
      );
    }
    final steadyFrames = trusted
        .where((frame) => frame.elapsed >= settleFrame.elapsed)
        .toList(growable: false);
    if (steadyFrames.length < 3) {
      return const PluckAnalysisOutcome.rejected(
        PluckRejectionReason.noSteadyReference,
      );
    }

    var attackFrames = trusted
        .where(
          (frame) =>
              frame.elapsed >= config.attackStart &&
              frame.elapsed <= config.attackEnd,
        )
        .toList(growable: false);
    if (attackFrames.isEmpty) {
      final firstValid = trusted.first.elapsed;
      final fallbackEnd = firstValid + config.fallbackAttackWindow;
      attackFrames = trusted
          .where(
            (frame) =>
                frame.elapsed >= firstValid && frame.elapsed <= fallbackEnd,
          )
          .toList(growable: false);
    }
    final attackPitch = _median(
      attackFrames.map((frame) => frame.cents!).toList(),
    );
    final attackOvershoot = (attackPitch - steadyReference).abs();
    final clarity = _median(
      trusted.map((frame) => frame.clarity).toList(growable: false),
    );
    final driftFrames = steadyFrames
        .where((frame) => frame.elapsed >= steadyReferenceStart)
        .toList(growable: false);
    return PluckAnalysisOutcome.accepted(
      PluckAnalysis(
        attackOvershootCents: attackOvershoot,
        settleTime: settleFrame.elapsed,
        steadyStatePitchCents: _median(
          steadyFrames.map((frame) => frame.cents!).toList(),
        ),
        steadyStateDriftCentsPerSecond: _linearSlope(
          driftFrames.length >= 3 ? driftFrames : steadyFrames,
        ),
        postAdjustmentStepObserved:
            detectPostAdjustmentStep && _hasStepJump(steadyFrames),
        peakRmsDb: peakRmsDb,
        confidence: clarity * validFrameRatio,
        validFrameRatio: validFrameRatio,
        validFrameCount: trusted.length,
      ),
    );
  }

  bool _isTrusted(PluckPitchFrame frame) {
    return frame.cents != null && frame.clarity >= config.minimumClarity;
  }

  PluckPitchFrame? _findSettleFrame(
    List<PluckPitchFrame> trusted,
    double steadyReference,
  ) {
    for (var startIndex = 0; startIndex < trusted.length; startIndex++) {
      final start = trusted[startIndex];
      if (start.elapsed < config.attackEnd) {
        continue;
      }
      final holdEnd = start.elapsed + config.settleHold;
      final held = trusted
          .skip(startIndex)
          .takeWhile((frame) => frame.elapsed <= holdEnd)
          .toList(growable: false);
      if (held.isEmpty || held.last.elapsed < holdEnd) {
        continue;
      }
      if (held.every(
        (frame) =>
            (frame.cents! - steadyReference).abs() <=
            config.settleToleranceCents,
      )) {
        return start;
      }
    }
    return null;
  }

  bool _hasStepJump(List<PluckPitchFrame> frames) {
    for (var index = 1; index < frames.length; index++) {
      final gap = frames[index].elapsed - frames[index - 1].elapsed;
      if (gap <= config.maximumAdjacentFrameGap &&
          (frames[index].cents! - frames[index - 1].cents!).abs() >
              config.stepJumpCents) {
        return true;
      }
    }
    return false;
  }
}

double _linearSlope(List<PluckPitchFrame> frames) {
  final originMicros = frames.first.elapsed.inMicroseconds;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumXY = 0.0;
  for (final frame in frames) {
    final x = (frame.elapsed.inMicroseconds - originMicros) / 1000000;
    final y = frame.cents!;
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumXY += x * y;
  }
  final count = frames.length.toDouble();
  final denominator = count * sumXX - sumX * sumX;
  if (denominator == 0) {
    return 0;
  }
  return (count * sumXY - sumX * sumY) / denominator;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
