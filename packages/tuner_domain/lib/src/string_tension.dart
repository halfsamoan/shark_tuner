import 'dart:math' as math;

import 'peg_guidance.dart';
import 'tuning_definition.dart';

abstract final class StringTensionMath {
  static const double gravityInchesPerSecondSquared = 386.4;
  static const double plainSteelDensityLbsPerCubicInch = 0.285;

  static double tensionLbf({
    required double unitWeightLbsPerInch,
    required double scaleLengthInches,
    required double frequencyHz,
  }) {
    _requirePositive(unitWeightLbsPerInch, 'unitWeightLbsPerInch');
    _requirePositive(scaleLengthInches, 'scaleLengthInches');
    _requirePositive(frequencyHz, 'frequencyHz');
    final waveLengthPerSecond = 2 * scaleLengthInches * frequencyHz;
    return unitWeightLbsPerInch *
        waveLengthPerSecond *
        waveLengthPerSecond /
        gravityInchesPerSecondSquared;
  }

  static double unitWeightForTargetTension({
    required double targetTensionLbf,
    required double scaleLengthInches,
    required double frequencyHz,
  }) {
    _requirePositive(targetTensionLbf, 'targetTensionLbf');
    _requirePositive(scaleLengthInches, 'scaleLengthInches');
    _requirePositive(frequencyHz, 'frequencyHz');
    final waveLengthPerSecond = 2 * scaleLengthInches * frequencyHz;
    return targetTensionLbf *
        gravityInchesPerSecondSquared /
        (waveLengthPerSecond * waveLengthPerSecond);
  }

  static double plainSteelUnitWeight({
    required double gaugeInches,
    double densityLbsPerCubicInch = plainSteelDensityLbsPerCubicInch,
  }) {
    _requirePositive(gaugeInches, 'gaugeInches');
    _requirePositive(densityLbsPerCubicInch, 'densityLbsPerCubicInch');
    final crossSectionSquareInches = math.pi * gaugeInches * gaugeInches / 4;
    return crossSectionSquareInches * densityLbsPerCubicInch;
  }
}

final class InstrumentScale {
  const InstrumentScale({
    required this.stringCount,
    required this.bassScaleInches,
    required this.trebleScaleInches,
  }) : assert(stringCount > 0),
       assert(bassScaleInches > 0),
       assert(trebleScaleInches > 0);

  final int stringCount;
  final double bassScaleInches;
  final double trebleScaleInches;

  double lengthForLowToHighIndex(int index) {
    if (index < 0 || index >= stringCount) {
      throw RangeError.index(index, List.filled(stringCount, null), 'index');
    }
    if (stringCount == 1) {
      return trebleScaleInches;
    }
    final progress = index / (stringCount - 1);
    return bassScaleInches + progress * (trebleScaleInches - bassScaleInches);
  }
}

enum UnitWeightSource { derived, measured, fitted }

final class StringGaugeSpec {
  const StringGaugeSpec({
    required this.gaugeInches,
    required this.construction,
    this.unitWeightLbsPerInch,
    this.unitWeightSource,
  }) : assert(gaugeInches > 0),
       assert(unitWeightLbsPerInch == null || unitWeightLbsPerInch > 0),
       assert(
         (unitWeightLbsPerInch == null) == (unitWeightSource == null),
         'A supplied unit weight and its source must be provided together.',
       );

  final double gaugeInches;
  final StringConstruction construction;
  final double? unitWeightLbsPerInch;
  final UnitWeightSource? unitWeightSource;

  ({double unitWeight, UnitWeightSource source}) resolveUnitWeight() {
    final supplied = unitWeightLbsPerInch;
    if (supplied != null) {
      return (unitWeight: supplied, source: unitWeightSource!);
    }
    if (construction == StringConstruction.wound) {
      throw StateError(
        'Wound strings require measured or fitted unit weight data.',
      );
    }
    return (
      unitWeight: StringTensionMath.plainSteelUnitWeight(
        gaugeInches: gaugeInches,
      ),
      source: UnitWeightSource.derived,
    );
  }
}

enum TensionBand { floppy, comfortable, firm, tight }

final class TensionBandThresholds {
  const TensionBandThresholds({
    this.plainFloppyBelowLbf = 12,
    this.woundFloppyBelowLbf = 14,
    this.comfortableAtMostLbf = 22,
    this.plainTightAboveLbf = 24,
    this.woundTightAboveLbf = 28,
  }) : assert(plainFloppyBelowLbf > 0),
       assert(woundFloppyBelowLbf > 0),
       assert(comfortableAtMostLbf > 0),
       assert(plainTightAboveLbf >= comfortableAtMostLbf),
       assert(woundTightAboveLbf >= comfortableAtMostLbf);

  final double plainFloppyBelowLbf;
  final double woundFloppyBelowLbf;
  final double comfortableAtMostLbf;
  final double plainTightAboveLbf;
  final double woundTightAboveLbf;
}

abstract final class TensionBandClassifier {
  static TensionBand classify({
    required double tensionLbf,
    required StringConstruction construction,
    TensionBandThresholds thresholds = const TensionBandThresholds(),
  }) {
    _requirePositive(tensionLbf, 'tensionLbf');
    final floppyBelow = construction == StringConstruction.plain
        ? thresholds.plainFloppyBelowLbf
        : thresholds.woundFloppyBelowLbf;
    final tightAbove = construction == StringConstruction.plain
        ? thresholds.plainTightAboveLbf
        : thresholds.woundTightAboveLbf;
    if (tensionLbf < floppyBelow) {
      return TensionBand.floppy;
    }
    if (tensionLbf <= thresholds.comfortableAtMostLbf) {
      return TensionBand.comfortable;
    }
    if (tensionLbf <= tightAbove) {
      return TensionBand.firm;
    }
    return TensionBand.tight;
  }
}

final class StringTensionResult {
  const StringTensionResult({
    required this.target,
    required this.gauge,
    required this.scaleLengthInches,
    required this.targetFrequencyHz,
    required this.unitWeightLbsPerInch,
    required this.unitWeightSource,
    required this.tensionLbf,
    required this.band,
  });

  final TuningString target;
  final StringGaugeSpec gauge;
  final double scaleLengthInches;
  final double targetFrequencyHz;
  final double unitWeightLbsPerInch;
  final UnitWeightSource unitWeightSource;
  final double tensionLbf;
  final TensionBand band;
}

abstract final class TensionProfileCalculator {
  static List<StringTensionResult> calculate({
    required TuningDefinition tuning,
    required InstrumentScale scale,
    required List<StringGaugeSpec> gaugesLowToHigh,
    TensionBandThresholds thresholds = const TensionBandThresholds(),
  }) {
    if (tuning.strings.length != scale.stringCount ||
        tuning.strings.length != gaugesLowToHigh.length) {
      throw ArgumentError(
        'Tuning, scale, and gauge set must have the same string count.',
      );
    }
    return List.unmodifiable([
      for (var index = 0; index < tuning.strings.length; index++)
        _calculateString(
          tuning: tuning,
          target: tuning.strings[index],
          gauge: gaugesLowToHigh[index],
          scaleLengthInches: scale.lengthForLowToHighIndex(index),
          thresholds: thresholds,
        ),
    ]);
  }

  static StringTensionResult _calculateString({
    required TuningDefinition tuning,
    required TuningString target,
    required StringGaugeSpec gauge,
    required double scaleLengthInches,
    required TensionBandThresholds thresholds,
  }) {
    final resolved = gauge.resolveUnitWeight();
    final targetFrequencyHz = target.targetFrequencyHz(
      referenceA4Hz: tuning.referenceA4Hz,
      centsOffset: tuning.centsOffset,
    );
    final tension = StringTensionMath.tensionLbf(
      unitWeightLbsPerInch: resolved.unitWeight,
      scaleLengthInches: scaleLengthInches,
      frequencyHz: targetFrequencyHz,
    );
    return StringTensionResult(
      target: target,
      gauge: gauge,
      scaleLengthInches: scaleLengthInches,
      targetFrequencyHz: targetFrequencyHz,
      unitWeightLbsPerInch: resolved.unitWeight,
      unitWeightSource: resolved.source,
      tensionLbf: tension,
      band: TensionBandClassifier.classify(
        tensionLbf: tension,
        construction: gauge.construction,
        thresholds: thresholds,
      ),
    );
  }
}

void _requirePositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Must be finite and positive.');
  }
}
