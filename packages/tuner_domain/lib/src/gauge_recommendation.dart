import 'dart:math' as math;

import 'built_in_tunings.dart';
import 'peg_guidance.dart';
import 'string_tension.dart';
import 'tuning_definition.dart';

final class UnitWeightModelMetadata {
  UnitWeightModelMetadata({
    required this.id,
    required this.version,
    required this.sourceUrl,
    required this.checkedAt,
    required this.minimumGaugeInches,
    required this.maximumGaugeInches,
    required this.method,
  });

  final String id;
  final int version;
  final String sourceUrl;
  final DateTime checkedAt;
  final double minimumGaugeInches;
  final double maximumGaugeInches;
  final String method;

  Uri get sourceUri => Uri.parse(sourceUrl);
}

/// A bounded log-interpolation model derived from Stringjoy's public nickel
/// roundwound calculator measurements. The source table is not reproduced.
/// Anchor selection and interpolation are project-owned and versioned here.
final class RoundwoundUnitWeightModel {
  const RoundwoundUnitWeightModel();

  static final UnitWeightModelMetadata _metadata = UnitWeightModelMetadata(
    id: 'stringjoy-nickel-roundwound-log-fit',
    version: 1,
    sourceUrl: 'https://tension.stringjoy.com/',
    checkedAt: DateTime.utc(2026, 7, 14),
    minimumGaugeInches: .018,
    maximumGaugeInches: .080,
    method: 'bounded piecewise log interpolation from selected measurements',
  );

  static const _anchors = <({double gauge, double unitWeight})>[
    (gauge: .018, unitWeight: .00008093),
    (gauge: .022, unitWeight: .00009605),
    (gauge: .026, unitWeight: .00013774),
    (gauge: .030, unitWeight: .00018104),
    (gauge: .034, unitWeight: .00023192),
    (gauge: .038, unitWeight: .00028110),
    (gauge: .042, unitWeight: .00034625),
    (gauge: .046, unitWeight: .00040108),
    (gauge: .050, unitWeight: .00047877),
    (gauge: .054, unitWeight: .00055734),
    (gauge: .058, unitWeight: .00064031),
    (gauge: .062, unitWeight: .00074720),
    (gauge: .068, unitWeight: .00084614),
    (gauge: .074, unitWeight: .00102422),
    (gauge: .080, unitWeight: .00116000),
  ];

  UnitWeightModelMetadata get metadata => _metadata;

  double unitWeightForGauge(double gaugeInches) {
    if (!gaugeInches.isFinite ||
        gaugeInches < metadata.minimumGaugeInches ||
        gaugeInches > metadata.maximumGaugeInches) {
      throw RangeError.value(
        gaugeInches,
        'gaugeInches',
        'Must stay within ${metadata.minimumGaugeInches}..'
            '${metadata.maximumGaugeInches}; the wound-string model never '
            'extrapolates beyond its fitted range.',
      );
    }
    if (gaugeInches == _anchors.last.gauge) {
      return _anchors.last.unitWeight;
    }
    for (var index = 0; index < _anchors.length - 1; index++) {
      final lower = _anchors[index];
      final upper = _anchors[index + 1];
      if (gaugeInches < lower.gauge || gaugeInches > upper.gauge) {
        continue;
      }
      final progress =
          (math.log(gaugeInches) - math.log(lower.gauge)) /
          (math.log(upper.gauge) - math.log(lower.gauge));
      return math.exp(
        math.log(lower.unitWeight) +
            progress *
                (math.log(upper.unitWeight) - math.log(lower.unitWeight)),
      );
    }
    throw StateError('No interpolation segment found for $gaugeInches.');
  }
}

final class GaugeSetDefinition {
  GaugeSetDefinition({
    required this.id,
    required this.displayName,
    required List<StringGaugeSpec> gaugesLowToHigh,
    this.isCustom = false,
    List<String> tags = const [],
  }) : gaugesLowToHigh = List.unmodifiable(gaugesLowToHigh),
       tags = List.unmodifiable(tags) {
    if (id.trim().isEmpty || displayName.trim().isEmpty) {
      throw ArgumentError('Gauge-set id and display name must not be empty.');
    }
    if (gaugesLowToHigh.isEmpty) {
      throw ArgumentError.value(gaugesLowToHigh, 'gaugesLowToHigh');
    }
  }

  factory GaugeSetDefinition.electricHighToLow({
    required String id,
    required String displayName,
    required List<double> gaugesHighToLow,
    bool woundThird = false,
    bool isCustom = true,
    List<String> tags = const [],
  }) {
    if (gaugesHighToLow.length < 4) {
      throw ArgumentError.value(
        gaugesHighToLow,
        'gaugesHighToLow',
        'Electric guitar sets need at least four strings.',
      );
    }
    final highToLow = <StringGaugeSpec>[
      for (var index = 0; index < gaugesHighToLow.length; index++)
        StringGaugeSpec(
          gaugeInches: gaugesHighToLow[index],
          construction: index > 2 || (index == 2 && woundThird)
              ? StringConstruction.wound
              : StringConstruction.plain,
        ),
    ];
    return GaugeSetDefinition(
      id: id,
      displayName: displayName,
      gaugesLowToHigh: highToLow.reversed.toList(growable: false),
      isCustom: isCustom,
      tags: tags,
    );
  }

  final String id;
  final String displayName;
  final List<StringGaugeSpec> gaugesLowToHigh;
  final bool isCustom;
  final List<String> tags;

  int get stringCount => gaugesLowToHigh.length;

  String get shortLabel {
    final high = (gaugesLowToHigh.last.gaugeInches * 1000).round();
    final low = (gaugesLowToHigh.first.gaugeInches * 1000).round();
    return '$high–$low';
  }
}

abstract final class GaugeSetCatalog {
  static const version = 1;

  static final light9_42 = _electric(
    'electric-9-42',
    '9–42 라이트',
    const [.009, .011, .016, .024, .032, .042],
    tags: const ['light'],
  );
  static final hybrid9_46 = _electric(
    'electric-9-46',
    '9–46 하이브리드',
    const [.009, .011, .016, .026, .036, .046],
    tags: const ['hybrid'],
  );
  static final regular10_46 = _electric(
    'electric-10-46',
    '10–46 레귤러',
    const [.010, .013, .017, .026, .036, .046],
    tags: const ['reference'],
  );
  static final heavyBottom10_52 = _electric(
    'electric-10-52',
    '10–52 헤비 바텀',
    const [.010, .013, .017, .030, .042, .052],
    tags: const ['heavy-bottom', 'drop'],
  );
  static final medium11_49 = _electric('electric-11-49', '11–49 미디엄', const [
    .011,
    .014,
    .018,
    .028,
    .038,
    .049,
  ]);
  static final drop11_54 = _electric(
    'electric-11-54',
    '11–54 드롭',
    const [.011, .014, .018, .030, .042, .054],
    tags: const ['drop'],
  );
  static final drop11_56 = _electric(
    'electric-11-56',
    '11–56 드롭',
    const [.011, .014, .018, .032, .044, .056],
    tags: const ['drop'],
  );
  static final heavy12_56 = _electric(
    'electric-12-56',
    '12–56 헤비',
    const [.012, .016, .020, .032, .044, .056],
    tags: const ['drop'],
  );
  static final heavy12_60 = _electric(
    'electric-12-60',
    '12–60 헤비',
    const [.012, .016, .020, .034, .046, .060],
    tags: const ['drop'],
  );
  static final heavy12_62 = _electric(
    'electric-12-62-wound-third',
    '12–62 와운드 3번',
    const [.012, .016, .024, .036, .048, .062],
    woundThird: true,
    tags: const ['drop', 'wound-third'],
  );
  static final baritone13_72 = _electric(
    'electric-13-72-wound-third',
    '13–72 바리톤',
    const [.013, .018, .030, .044, .056, .072],
    woundThird: true,
    tags: const ['baritone', 'wound-third'],
  );

  static final seven9_54 = _electric('electric-7-9-54', '7현 9–54', const [
    .009,
    .011,
    .016,
    .024,
    .032,
    .042,
    .054,
  ]);
  static final seven10_59 = _electric(
    'electric-7-10-59',
    '7현 10–59',
    const [.010, .013, .017, .026, .036, .046, .059],
    tags: const ['drop'],
  );
  static final seven10_62 = _electric(
    'electric-7-10-62',
    '7현 10–62',
    const [.010, .013, .017, .028, .038, .050, .062],
    tags: const ['drop'],
  );
  static final seven11_64 = _electric(
    'electric-7-11-64',
    '7현 11–64',
    const [.011, .014, .018, .030, .042, .052, .064],
    tags: const ['drop'],
  );

  static final eight9_65 = _electric('electric-8-9-65', '8현 9–65', const [
    .009,
    .011,
    .016,
    .024,
    .032,
    .042,
    .054,
    .065,
  ]);
  static final eight10_74 = _electric(
    'electric-8-10-74',
    '8현 10–74',
    const [.010, .013, .017, .026, .036, .046, .059, .074],
    tags: const ['drop'],
  );
  static final eight9_80 = _electric(
    'electric-8-9-80',
    '8현 9–80 헤비 바텀',
    const [.009, .011, .016, .024, .034, .046, .060, .080],
    tags: const ['heavy-bottom', 'drop'],
  );

  static final List<GaugeSetDefinition> all = List.unmodifiable([
    light9_42,
    hybrid9_46,
    regular10_46,
    heavyBottom10_52,
    medium11_49,
    drop11_54,
    drop11_56,
    heavy12_56,
    heavy12_60,
    heavy12_62,
    baritone13_72,
    seven9_54,
    seven10_59,
    seven10_62,
    seven11_64,
    eight9_65,
    eight10_74,
    eight9_80,
  ]);

  static List<GaugeSetDefinition> forStringCount(int stringCount) {
    return List.unmodifiable(
      all.where((gaugeSet) => gaugeSet.stringCount == stringCount),
    );
  }

  static GaugeSetDefinition _electric(
    String id,
    String displayName,
    List<double> gaugesHighToLow, {
    bool woundThird = false,
    List<String> tags = const [],
  }) {
    return GaugeSetDefinition.electricHighToLow(
      id: id,
      displayName: displayName,
      gaugesHighToLow: gaugesHighToLow,
      woundThird: woundThird,
      isCustom: false,
      tags: tags,
    );
  }
}

final class GaugeRecommendation {
  GaugeRecommendation({
    required this.gaugeSet,
    required List<StringTensionResult> strings,
    required this.score,
    required this.reason,
    required List<int> floppyStringNumbers,
    required List<String> guardrailNotes,
    required this.unitWeightModel,
  }) : strings = List.unmodifiable(strings),
       floppyStringNumbers = List.unmodifiable(floppyStringNumbers),
       guardrailNotes = List.unmodifiable(guardrailNotes);

  final GaugeSetDefinition gaugeSet;
  final List<StringTensionResult> strings;
  final double score;
  final String reason;
  final List<int> floppyStringNumbers;
  final List<String> guardrailNotes;
  final UnitWeightModelMetadata unitWeightModel;

  double get totalTensionLbf =>
      strings.fold(0, (total, result) => total + result.tensionLbf);
}

abstract final class GaugeRecommendationEngine {
  static const _model = RoundwoundUnitWeightModel();
  static const _plainGaugeOptions = <double>[
    .007,
    .008,
    .009,
    .010,
    .011,
    .012,
    .013,
    .014,
    .015,
    .016,
    .017,
    .018,
    .019,
    .020,
    .022,
    .024,
  ];
  static const _woundGaugeOptions = <double>[
    .018,
    .020,
    .022,
    .024,
    .026,
    .028,
    .030,
    .032,
    .034,
    .036,
    .038,
    .040,
    .042,
    .044,
    .046,
    .048,
    .050,
    .052,
    .054,
    .056,
    .058,
    .059,
    .060,
    .062,
    .064,
    .065,
    .068,
    .070,
    .072,
    .074,
    .080,
  ];

  static List<GaugeRecommendation> recommend({
    required TuningDefinition targetTuning,
    required InstrumentScale scale,
    TuningDefinition? currentTuning,
    GaugeSetDefinition? currentGaugeSet,
    List<GaugeSetDefinition>? candidates,
    int count = 3,
  }) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count');
    }
    final referenceTuning = currentTuning ?? BuiltInTunings.standardGuitar;
    final referenceSet = currentGaugeSet ?? GaugeSetCatalog.regular10_46;
    _validateCounts(referenceTuning, scale, referenceSet);
    _validateCounts(targetTuning, scale, referenceSet);
    final referenceTensions = _calculateProfile(
      tuning: referenceTuning,
      scale: scale,
      gaugeSet: referenceSet,
    );
    final available =
        candidates ?? GaugeSetCatalog.forStringCount(scale.stringCount);
    final recommendations = <GaugeRecommendation>[
      for (final candidate in available)
        if (candidate.stringCount == scale.stringCount)
          _scoreCandidate(
            targetTuning: targetTuning,
            scale: scale,
            candidate: candidate,
            referenceTensions: referenceTensions,
          ),
    ]..sort((left, right) => left.score.compareTo(right.score));
    return List.unmodifiable(recommendations.take(count));
  }

  static GaugeRecommendation customMatch({
    required TuningDefinition targetTuning,
    required InstrumentScale scale,
    TuningDefinition? currentTuning,
    GaugeSetDefinition? currentGaugeSet,
  }) {
    final referenceTuning = currentTuning ?? BuiltInTunings.standardGuitar;
    final referenceSet = currentGaugeSet ?? GaugeSetCatalog.regular10_46;
    _validateCounts(referenceTuning, scale, referenceSet);
    _validateCounts(targetTuning, scale, referenceSet);
    final referenceTensions = _calculateProfile(
      tuning: referenceTuning,
      scale: scale,
      gaugeSet: referenceSet,
    );
    final customGauges = <StringGaugeSpec>[];
    for (var index = 0; index < targetTuning.strings.length; index++) {
      final target = targetTuning.strings[index];
      final construction = referenceSet.gaugesLowToHigh[index].construction;
      final targetFrequency = target.targetFrequencyHz(
        referenceA4Hz: targetTuning.referenceA4Hz,
        centsOffset: targetTuning.centsOffset,
      );
      final targetUnitWeight = StringTensionMath.unitWeightForTargetTension(
        targetTensionLbf: referenceTensions[index].tensionLbf,
        scaleLengthInches: scale.lengthForLowToHighIndex(index),
        frequencyHz: targetFrequency,
      );
      final options = construction == StringConstruction.plain
          ? _plainGaugeOptions
          : _woundGaugeOptions;
      final gauge = options.reduce((best, candidate) {
        final bestDifference =
            (_unitWeight(best, construction) - targetUnitWeight).abs();
        final candidateDifference =
            (_unitWeight(candidate, construction) - targetUnitWeight).abs();
        return candidateDifference < bestDifference ? candidate : best;
      });
      customGauges.add(
        StringGaugeSpec(gaugeInches: gauge, construction: construction),
      );
    }
    final custom = GaugeSetDefinition(
      id: 'custom-${targetTuning.id}-${scale.bassScaleInches}',
      displayName: '현별 맞춤 단품 조합',
      gaugesLowToHigh: customGauges,
      isCustom: true,
      tags: const ['custom', 'matched-feel'],
    );
    final scored = _scoreCandidate(
      targetTuning: targetTuning,
      scale: scale,
      candidate: custom,
      referenceTensions: referenceTensions,
    );
    return GaugeRecommendation(
      gaugeSet: scored.gaugeSet,
      strings: scored.strings,
      score: scored.score,
      reason: '현재 장력 감각을 현별 목표로 역산한 맞춤 단품 조합입니다.',
      floppyStringNumbers: scored.floppyStringNumbers,
      guardrailNotes: scored.guardrailNotes,
      unitWeightModel: scored.unitWeightModel,
    );
  }

  static GaugeRecommendation _scoreCandidate({
    required TuningDefinition targetTuning,
    required InstrumentScale scale,
    required GaugeSetDefinition candidate,
    required List<StringTensionResult> referenceTensions,
  }) {
    final strings = _calculateProfile(
      tuning: targetTuning,
      scale: scale,
      gaugeSet: candidate,
    );
    var score = 0.0;
    final floppy = <int>[];
    for (var index = 0; index < strings.length; index++) {
      final difference =
          strings[index].tensionLbf - referenceTensions[index].tensionLbf;
      final weight = index == 0 ? 1.6 : 1.0;
      score += weight * difference * difference;
      if (strings[index].band == TensionBand.floppy) {
        floppy.add(strings[index].target.stringNumber);
        score += 400;
      } else if (strings[index].band == TensionBand.tight) {
        score += 80;
      }
    }
    final guardrails = _guardrailNotes(
      tuning: targetTuning,
      scale: scale,
      gaugeSet: candidate,
    );
    if (_violatesMinimumLowGauge(targetTuning, scale, candidate)) {
      score += 10000;
    }
    final reason = floppy.isEmpty
        ? '현재 장력 감각에 가깝고 느슨한 현이 없는 조합입니다.'
        : '현재 장력 감각과 비교했지만 ${floppy.join(', ')}번 줄은 느슨할 수 있습니다.';
    return GaugeRecommendation(
      gaugeSet: candidate,
      strings: strings,
      score: score,
      reason: reason,
      floppyStringNumbers: floppy,
      guardrailNotes: guardrails,
      unitWeightModel: _model.metadata,
    );
  }

  static List<StringTensionResult> _calculateProfile({
    required TuningDefinition tuning,
    required InstrumentScale scale,
    required GaugeSetDefinition gaugeSet,
  }) {
    final resolved = [
      for (final gauge in gaugeSet.gaugesLowToHigh)
        if (gauge.construction == StringConstruction.wound &&
            gauge.unitWeightLbsPerInch == null)
          StringGaugeSpec(
            gaugeInches: gauge.gaugeInches,
            construction: gauge.construction,
            unitWeightLbsPerInch: _model.unitWeightForGauge(gauge.gaugeInches),
            unitWeightSource: UnitWeightSource.fitted,
          )
        else
          gauge,
    ];
    return TensionProfileCalculator.calculate(
      tuning: tuning,
      scale: scale,
      gaugesLowToHigh: resolved,
    );
  }

  static double _unitWeight(double gauge, StringConstruction construction) {
    return construction == StringConstruction.plain
        ? StringTensionMath.plainSteelUnitWeight(gaugeInches: gauge)
        : _model.unitWeightForGauge(gauge);
  }

  static bool _violatesMinimumLowGauge(
    TuningDefinition tuning,
    InstrumentScale scale,
    GaugeSetDefinition gaugeSet,
  ) {
    final lowestMidi = tuning.strings.first.midiNote;
    final lowestGauge = gaugeSet.gaugesLowToHigh.first.gaugeInches;
    if (tuning.strings.length == 6 && lowestMidi <= 33) {
      return lowestGauge < .062;
    }
    if (tuning.strings.length == 6 && lowestMidi <= 36) {
      return lowestGauge < .056;
    }
    if (tuning.strings.length == 7 && lowestMidi <= 33) {
      return lowestGauge < .059;
    }
    if (tuning.strings.length >= 8 && lowestMidi <= 30) {
      return lowestGauge < .065 || scale.bassScaleInches < 26.5;
    }
    return false;
  }

  static List<String> _guardrailNotes({
    required TuningDefinition tuning,
    required InstrumentScale scale,
    required GaugeSetDefinition gaugeSet,
  }) {
    final notes = <String>[];
    final lowestMidi = tuning.strings.first.midiNote;
    final lowestGauge = gaugeSet.gaugesLowToHigh.first.gaugeInches;
    if (tuning.strings.length == 6 && lowestMidi <= 33) {
      notes.add(
        lowestGauge < .062
            ? '6현 Drop A 저음은 최소 .062를 권장합니다.'
            : '6현 Drop A 최소 .062 가드레일을 충족합니다.',
      );
      if (scale.bassScaleInches < 26.5) {
        notes.add('Drop A는 26.5인치 이상에서 더 안정적일 수 있습니다.');
      }
    } else if (tuning.strings.length == 6 && lowestMidi <= 36) {
      notes.add(
        lowestGauge < .056
            ? '6현 Drop C 저음은 최소 .056을 권장합니다.'
            : '6현 Drop C 최소 .056 가드레일을 충족합니다.',
      );
    } else if (tuning.strings.length == 7 && lowestMidi <= 33) {
      notes.add(
        lowestGauge < .059
            ? '7현 Drop A 저음은 최소 .059를 권장합니다.'
            : '7현 Drop A 최소 .059 가드레일을 충족합니다.',
      );
    } else if (tuning.strings.length >= 8 && lowestMidi <= 30) {
      notes.add('8현 F♯1 이하에서는 .065 이상과 26.5인치 이상을 확인하세요.');
    }
    return notes;
  }

  static void _validateCounts(
    TuningDefinition tuning,
    InstrumentScale scale,
    GaugeSetDefinition gaugeSet,
  ) {
    if (tuning.strings.length != scale.stringCount ||
        gaugeSet.stringCount != scale.stringCount) {
      throw ArgumentError(
        'Tuning, scale, and gauge set must have the same string count.',
      );
    }
  }
}
