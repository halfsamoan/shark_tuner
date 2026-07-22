enum PegSide { bass, treble }

enum InstrumentHandedness { right, left }

enum HeadstockOrientation { standard, reversed }

enum StringWinding { standard, reversed }

enum PegMechanism { verticalPost, slottedRoller }

enum HeadstockLayout { split, inline, classicalSplit }

enum PegRotationDirection {
  clockwise,
  counterClockwise;

  PegRotationDirection get opposite => switch (this) {
    clockwise => counterClockwise,
    counterClockwise => clockwise,
  };
}

enum StringConstruction { plain, wound }

final class PegConfiguration {
  const PegConfiguration({
    required this.side,
    this.handedness = InstrumentHandedness.right,
    this.orientation = HeadstockOrientation.standard,
    this.winding = StringWinding.standard,
    this.mechanism = PegMechanism.verticalPost,
    this.directionOverride,
  });

  final PegSide side;
  final InstrumentHandedness handedness;
  final HeadstockOrientation orientation;
  final StringWinding winding;
  final PegMechanism mechanism;
  final PegRotationDirection? directionOverride;

  PegConfiguration copyWith({
    PegSide? side,
    InstrumentHandedness? handedness,
    HeadstockOrientation? orientation,
    StringWinding? winding,
    PegMechanism? mechanism,
    PegRotationDirection? directionOverride,
  }) {
    return PegConfiguration(
      side: side ?? this.side,
      handedness: handedness ?? this.handedness,
      orientation: orientation ?? this.orientation,
      winding: winding ?? this.winding,
      mechanism: mechanism ?? this.mechanism,
      directionOverride: directionOverride ?? this.directionOverride,
    );
  }
}

/// A verified physical map from guitar strings to tuning-machine behavior.
///
/// Split layouts cover 3+3, 4+3, and 4+4 headstocks. Inline layouts support
/// any string count. Classical slotted rollers deliberately remain unknown
/// until a direction override has been observed for each peg.
final class InstrumentPegProfile {
  InstrumentPegProfile._({
    required this.stringCount,
    required this.layout,
    required this.bassSideStringCount,
    required this.handedness,
    required this.orientation,
    required Map<int, StringWinding> windingOverrides,
    required Map<int, PegRotationDirection> directionOverrides,
  }) : windingOverrides = Map.unmodifiable(windingOverrides),
       directionOverrides = Map.unmodifiable(directionOverrides) {
    if (stringCount <= 0) {
      throw ArgumentError.value(stringCount, 'stringCount');
    }
    if (layout != HeadstockLayout.inline &&
        (bassSideStringCount <= 0 || bassSideStringCount >= stringCount)) {
      throw ArgumentError.value(
        bassSideStringCount,
        'bassSideStringCount',
        'A split layout needs pegs on both sides.',
      );
    }
    if (layout == HeadstockLayout.inline &&
        bassSideStringCount != stringCount) {
      throw ArgumentError.value(
        bassSideStringCount,
        'bassSideStringCount',
        'Inline layouts place every peg on one side.',
      );
    }
    for (final stringNumber in {
      ...windingOverrides.keys,
      ...directionOverrides.keys,
    }) {
      _checkStringNumber(stringNumber);
    }
  }

  factory InstrumentPegProfile.split({
    required int stringCount,
    required int bassSideStringCount,
    InstrumentHandedness handedness = InstrumentHandedness.right,
    HeadstockOrientation orientation = HeadstockOrientation.standard,
    Map<int, StringWinding> windingOverrides = const {},
    Map<int, PegRotationDirection> directionOverrides = const {},
  }) {
    return InstrumentPegProfile._(
      stringCount: stringCount,
      layout: HeadstockLayout.split,
      bassSideStringCount: bassSideStringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    );
  }

  factory InstrumentPegProfile.inline({
    required int stringCount,
    InstrumentHandedness handedness = InstrumentHandedness.right,
    HeadstockOrientation orientation = HeadstockOrientation.standard,
    Map<int, StringWinding> windingOverrides = const {},
    Map<int, PegRotationDirection> directionOverrides = const {},
  }) {
    return InstrumentPegProfile._(
      stringCount: stringCount,
      layout: HeadstockLayout.inline,
      bassSideStringCount: stringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    );
  }

  factory InstrumentPegProfile.classicalSplit({
    required int stringCount,
    required int bassSideStringCount,
    InstrumentHandedness handedness = InstrumentHandedness.right,
    HeadstockOrientation orientation = HeadstockOrientation.standard,
    Map<int, StringWinding> windingOverrides = const {},
    Map<int, PegRotationDirection> directionOverrides = const {},
  }) {
    return InstrumentPegProfile._(
      stringCount: stringCount,
      layout: HeadstockLayout.classicalSplit,
      bassSideStringCount: bassSideStringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    );
  }

  final int stringCount;
  final HeadstockLayout layout;
  final int bassSideStringCount;
  final InstrumentHandedness handedness;
  final HeadstockOrientation orientation;
  final Map<int, StringWinding> windingOverrides;
  final Map<int, PegRotationDirection> directionOverrides;

  PegConfiguration configurationForString(int stringNumber) {
    _checkStringNumber(stringNumber);
    final side = layout == HeadstockLayout.inline
        ? PegSide.bass
        : stringNumber > stringCount - bassSideStringCount
        ? PegSide.bass
        : PegSide.treble;
    return PegConfiguration(
      side: side,
      handedness: handedness,
      orientation: orientation,
      winding: windingOverrides[stringNumber] ?? StringWinding.standard,
      mechanism: layout == HeadstockLayout.classicalSplit
          ? PegMechanism.slottedRoller
          : PegMechanism.verticalPost,
      directionOverride: directionOverrides[stringNumber],
    );
  }

  PegRotationDirection raisePitchDirectionForString(int stringNumber) {
    return PegDirectionRule.raisePitchDirection(
      configurationForString(stringNumber),
    );
  }

  InstrumentPegProfile withDirectionOverride({
    required int stringNumber,
    required PegRotationDirection raisePitchDirection,
  }) {
    _checkStringNumber(stringNumber);
    return InstrumentPegProfile._(
      stringCount: stringCount,
      layout: layout,
      bassSideStringCount: bassSideStringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: {
        ...directionOverrides,
        stringNumber: raisePitchDirection,
      },
    );
  }

  void _checkStringNumber(int stringNumber) {
    if (stringNumber < 1 || stringNumber > stringCount) {
      throw RangeError.range(stringNumber, 1, stringCount, 'stringNumber');
    }
  }
}

abstract final class PegDirectionRule {
  static PegRotationDirection raisePitchDirection(
    PegConfiguration configuration,
  ) {
    final override = configuration.directionOverride;
    if (override != null) {
      return override;
    }
    if (configuration.mechanism == PegMechanism.slottedRoller) {
      throw StateError(
        'Slotted rollers require a verified per-peg direction override.',
      );
    }

    var direction = configuration.side == PegSide.bass
        ? PegRotationDirection.counterClockwise
        : PegRotationDirection.clockwise;
    final shouldFlip = [
      configuration.handedness == InstrumentHandedness.left,
      configuration.orientation == HeadstockOrientation.reversed,
      configuration.winding == StringWinding.reversed,
    ].where((value) => value).length.isOdd;
    if (shouldFlip) {
      direction = direction.opposite;
    }
    return direction;
  }
}

enum PegDirectionMonitorState { observing, flipSuggested }

/// Detects a likely reversed string winding without continuing unsafe guidance.
final class PegDirectionMonitor {
  PegDirectionMonitor(
    this._raisePitchDirection, {
    this.minimumObservedDeltaCents = 2,
    this.contradictionsBeforeSuggestion = 2,
  }) {
    if (minimumObservedDeltaCents <= 0 || contradictionsBeforeSuggestion <= 0) {
      throw ArgumentError('Monitor thresholds must be positive.');
    }
  }

  final double minimumObservedDeltaCents;
  final int contradictionsBeforeSuggestion;
  PegRotationDirection _raisePitchDirection;
  int _consecutiveContradictions = 0;
  bool _hasRuntimeOverride = false;
  bool _guidancePaused = false;

  PegRotationDirection get raisePitchDirection => _raisePitchDirection;
  int get consecutiveContradictions => _consecutiveContradictions;
  bool get hasRuntimeOverride => _hasRuntimeOverride;
  bool get guidancePaused => _guidancePaused;

  PegDirectionMonitorState recordAdjustment({
    required PegRotationDirection direction,
    required double pitchDeltaCents,
  }) {
    if (!pitchDeltaCents.isFinite) {
      throw ArgumentError.value(pitchDeltaCents, 'pitchDeltaCents');
    }
    if (_guidancePaused) {
      return PegDirectionMonitorState.flipSuggested;
    }
    if (pitchDeltaCents.abs() < minimumObservedDeltaCents) {
      return PegDirectionMonitorState.observing;
    }

    final expectedPitchRise = direction == _raisePitchDirection;
    final observedPitchRise = pitchDeltaCents > 0;
    if (expectedPitchRise == observedPitchRise) {
      _consecutiveContradictions = 0;
      return PegDirectionMonitorState.observing;
    }

    _consecutiveContradictions++;
    if (_consecutiveContradictions >= contradictionsBeforeSuggestion) {
      _guidancePaused = true;
      return PegDirectionMonitorState.flipSuggested;
    }
    return PegDirectionMonitorState.observing;
  }

  void acceptSuggestedFlip() {
    if (!_guidancePaused) {
      throw StateError('No direction flip is currently suggested.');
    }
    _raisePitchDirection = _raisePitchDirection.opposite;
    _hasRuntimeOverride = true;
    _consecutiveContradictions = 0;
    _guidancePaused = false;
  }

  void dismissSuggestion() {
    _consecutiveContradictions = 0;
    _guidancePaused = false;
  }
}

final class PegRotationHint {
  const PegRotationHint._({
    required this.buttonTurns,
    required this.isCalibrated,
  });

  final double buttonTurns;
  final bool isCalibrated;

  factory PegRotationHint.estimate({
    required double centsToTarget,
    required StringConstruction construction,
    double? calibratedCentsPerTurn,
  }) {
    if (!centsToTarget.isFinite) {
      throw ArgumentError.value(centsToTarget, 'centsToTarget');
    }
    if (calibratedCentsPerTurn != null && calibratedCentsPerTurn <= 0) {
      throw ArgumentError.value(
        calibratedCentsPerTurn,
        'calibratedCentsPerTurn',
      );
    }
    final centsPerTurn =
        calibratedCentsPerTurn ??
        switch (construction) {
          StringConstruction.plain => 200,
          StringConstruction.wound => 400,
        };
    return PegRotationHint._(
      buttonTurns: (centsToTarget.abs() / centsPerTurn).clamp(0, 1),
      isCalibrated: calibratedCentsPerTurn != null,
    );
  }
}
