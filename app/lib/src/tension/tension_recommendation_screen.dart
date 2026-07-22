import 'package:flutter/material.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../string_care/string_care_screen.dart';
import '../string_care/string_care_store.dart';
import '../ui/instrument_widgets.dart';

class TensionRecommendationScreen extends StatefulWidget {
  const TensionRecommendationScreen({
    super.key,
    required this.tuning,
    this.stringCareLoader = loadStringCareLedger,
    this.stringCareSaver = saveStringCareLedger,
    this.stringCareNow = DateTime.now,
  });

  final TuningDefinition tuning;
  final StringCareLoader stringCareLoader;
  final StringCareSaver stringCareSaver;
  final DateTime Function() stringCareNow;

  @override
  State<TensionRecommendationScreen> createState() =>
      _TensionRecommendationScreenState();
}

class _TensionRecommendationScreenState
    extends State<TensionRecommendationScreen> {
  static const _scaleOptions = [24.75, 25.5, 26.5, 27.0, 28.0];

  late GaugeSetDefinition _currentGaugeSet;
  final _customGaugeController = TextEditingController();
  var _scaleLength = 25.5;
  var _customMode = false;
  var _woundThird = false;
  String? _customGaugeError;

  @override
  void initState() {
    super.initState();
    _currentGaugeSet = _defaultGaugeSet(widget.tuning.strings.length);
    _customGaugeController.text = _gaugeInputValue(_currentGaugeSet);
  }

  @override
  void dispose() {
    _customGaugeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = InstrumentScale(
      stringCount: widget.tuning.strings.length,
      bassScaleInches: _scaleLength,
      trebleScaleInches: _scaleLength,
    );
    final currentTuning = _standardReference(widget.tuning.strings.length);
    final recommendations = GaugeRecommendationEngine.recommend(
      targetTuning: widget.tuning,
      scale: scale,
      currentTuning: currentTuning,
      currentGaugeSet: _currentGaugeSet,
    );
    final customMatch = GaugeRecommendationEngine.customMatch(
      targetTuning: widget.tuning,
      scale: scale,
      currentTuning: currentTuning,
      currentGaugeSet: _currentGaugeSet,
    );
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '장력·게이지 추천', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            InstrumentSectionLabel(
              'Tension design  /  ${widget.tuning.name}',
              color: context.terminal.accent,
            ),
            const SizedBox(height: 10),
            Text(
              '현재 손에 익은 장력 감각을 ${widget.tuning.name.toUpperCase()}에서도 유지할 조합을 찾습니다.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '장력은 현의 굵기뿐 아니라 스케일 길이와 목표 음정으로 계산합니다. 숫자는 이상적인 장력 추정치이며 실제 촉감은 코어와 제조사에 따라 달라집니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
              ),
            ),
            const SizedBox(height: 24),
            InstrumentSectionLabel('01  /  내 기타 기준'),
            const SizedBox(height: 8),
            _ScaleSelector(
              options: _scaleOptions,
              selected: _scaleLength,
              onSelected: (value) => setState(() => _scaleLength = value),
            ),
            const SizedBox(height: 12),
            _CurrentGaugeStrip(
              gaugeSet: _currentGaugeSet,
              customMode: _customMode,
              onToggleCustom: () {
                setState(() {
                  _customMode = !_customMode;
                  _customGaugeError = null;
                });
              },
            ),
            if (_customMode) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('custom-gauge-input'),
                controller: _customGaugeController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: '현재 게이지 (${widget.tuning.strings.length}개)',
                  hintText: '10-13-17-26-36-46',
                  errorText: _customGaugeError,
                  helperText: '입력은 높은 줄 → 낮은 줄, 숫자는 1/1000 inch',
                ),
              ),
              if (widget.tuning.strings.length >= 6)
                CheckboxListTile(
                  value: _woundThird,
                  onChanged: (value) =>
                      setState(() => _woundThird = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '3번 줄을 wound로 계산',
                    style: context.instrumentType.caption,
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('apply-custom-gauges'),
                  onPressed: _applyCustomGaugeSet,
                  child: const Text('현재 감각 기준으로 적용'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            InstrumentSectionLabel(
              '02  /  추천 세트',
              color: context.terminal.accent,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < recommendations.length; index++) ...[
              _RecommendationSection(
                key: Key('gauge-recommendation-${index + 1}'),
                rank: index + 1,
                recommendation: recommendations[index],
                expanded: index == 0,
                onRecordInstallation: _openStringCare,
              ),
              if (index != recommendations.length - 1)
                const SizedBox(height: 8),
            ],
            const SizedBox(height: 24),
            InstrumentSectionLabel('03  /  세트에 없는 현별 조합'),
            const SizedBox(height: 8),
            _RecommendationSection(
              rank: 0,
              recommendation: customMatch,
              expanded: false,
              onRecordInstallation: _openStringCare,
            ),
            const SizedBox(height: 24),
            _ModelNotice(metadata: recommendations.first.unitWeightModel),
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: '장력 계산됨',
        detail:
            '${widget.tuning.strings.length}현 │ ${_scaleLength.toStringAsFixed(_scaleLength % 1 == 0 ? 0 : 2)}″ │ ${_currentGaugeSet.shortLabel}',
      ),
    );
  }

  void _applyCustomGaugeSet() {
    final values = _customGaugeController.text
        .split(RegExp(r'[-,\s/]+'))
        .where((part) => part.isNotEmpty)
        .map(double.tryParse)
        .toList(growable: false);
    if (values.length != widget.tuning.strings.length ||
        values.any((value) => value == null)) {
      setState(() {
        _customGaugeError =
            '${widget.tuning.strings.length}개 게이지를 높은 줄부터 입력해 주세요.';
      });
      return;
    }
    final gauges = values
        .cast<double>()
        .map((value) => value >= 1 ? value / 1000 : value)
        .toList(growable: false);
    if (gauges.any((gauge) => gauge < .007 || gauge > .080)) {
      setState(() {
        _customGaugeError = '게이지 형식을 확인해 주세요. 지원 범위는 7–80입니다.';
      });
      return;
    }
    final high = (gauges.first * 1000).round();
    final low = (gauges.last * 1000).round();
    setState(() {
      _currentGaugeSet = GaugeSetDefinition.electricHighToLow(
        id: 'user-current-$high-$low',
        displayName: '사용자 설정 $high–$low',
        gaugesHighToLow: gauges,
        woundThird: _woundThird,
      );
      _customGaugeError = null;
    });
  }

  void _openStringCare(GaugeRecommendation recommendation) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StringCareScreen(
          loader: widget.stringCareLoader,
          saver: widget.stringCareSaver,
          now: widget.stringCareNow,
          suggestedGaugeLabel: recommendation.gaugeSet.shortLabel,
          suggestedTuningId: widget.tuning.id,
        ),
      ),
    );
  }
}

class _ScaleSelector extends StatelessWidget {
  const _ScaleSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<double> options;
  final double selected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '스케일 길이',
          style: context.instrumentType.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final option in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Semantics(
                    button: true,
                    selected: selected == option,
                    child: InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected == option
                              ? context.terminal.accent
                              : context.terminal.panel,
                          border: Border.all(
                            color: selected == option
                                ? context.terminal.accent
                                : context.terminal.line,
                          ),
                        ),
                        child: Text(
                          '${option.toStringAsFixed(option % 1 == 0 ? 0 : 2)}″',
                          style: context.instrumentType.status.copyWith(
                            color: selected == option
                                ? context.terminal.accentInk
                                : context.terminal.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CurrentGaugeStrip extends StatelessWidget {
  const _CurrentGaugeStrip({
    required this.gaugeSet,
    required this.customMode,
    required this.onToggleCustom,
  });

  final GaugeSetDefinition gaugeSet;
  final bool customMode;
  final VoidCallback onToggleCustom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.terminal.panel,
        border: Border.all(color: context.terminal.line),
      ),
      child: Row(
        children: [
          Text(
            '현재 현',
            style: context.instrumentType.status.copyWith(
              color: context.terminal.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gaugeSet.displayName,
              style: context.instrumentType.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            key: const Key('custom-gauge-toggle'),
            onPressed: onToggleCustom,
            child: Text(customMode ? '입력 닫기' : '직접 입력'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    super.key,
    required this.rank,
    required this.recommendation,
    required this.expanded,
    required this.onRecordInstallation,
  });

  final int rank;
  final GaugeRecommendation recommendation;
  final bool expanded;
  final ValueChanged<GaugeRecommendation> onRecordInstallation;

  @override
  Widget build(BuildContext context) {
    final warning = recommendation.floppyStringNumbers.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: context.terminal.panel,
        border: Border.all(
          color: warning ? context.terminal.amber : context.terminal.line,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: Border(),
        collapsedShape: Border(),
        leading: SizedBox(
          width: 30,
          child: Text(
            rank == 0 ? 'C' : rank.toString().padLeft(2, '0'),
            style: context.instrumentType.caption.copyWith(
              color: rank == 1
                  ? context.terminal.accent
                  : context.terminal.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          recommendation.gaugeSet.displayName,
          style: context.instrumentType.caption.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${recommendation.totalTensionLbf.toStringAsFixed(1)} lbf total · ${warning ? '느슨한 현 확인' : 'floppy 경고 없음'}',
          style: context.instrumentType.status.copyWith(
            color: warning ? context.terminal.amber : context.terminal.muted,
          ),
        ),
        children: [
          Divider(height: 1),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              recommendation.reason,
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
              ),
            ),
          ),
          for (final note in recommendation.guardrailNotes) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '! $note',
                style: context.instrumentType.caption.copyWith(
                  color: context.terminal.amber,
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          const _TensionTableHeader(),
          for (final result in recommendation.strings)
            _TensionTableRow(result: result),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              key: Key(
                'record-gauge-installation-${rank == 0 ? 'custom' : rank.toString().padLeft(2, '0')}',
              ),
              onPressed: () => onRecordInstallation(recommendation),
              child: const Text('이 세트 설치 기록'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TensionTableHeader extends StatelessWidget {
  const _TensionTableHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 38, child: InstrumentSectionLabel('현')),
        SizedBox(width: 48, child: InstrumentSectionLabel('음')),
        Expanded(child: InstrumentSectionLabel('게이지')),
        SizedBox(width: 52, child: InstrumentSectionLabel('lbf')),
        SizedBox(width: 54, child: InstrumentSectionLabel('상태')),
      ],
    );
  }
}

class _TensionTableRow extends StatelessWidget {
  const _TensionTableRow({required this.result});

  final StringTensionResult result;

  @override
  Widget build(BuildContext context) {
    final cellStyle = context.instrumentType.status.copyWith(
      color: context.terminal.text,
    );
    final (label, color) = switch (result.band) {
      TensionBand.floppy => ('느슨', context.terminal.amber),
      TensionBand.comfortable => ('적정', context.terminal.accent),
      TensionBand.firm => ('단단', context.terminal.text),
      TensionBand.tight => ('과함', context.terminal.danger),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.terminal.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text('${result.target.stringNumber}', style: cellStyle),
          ),
          SizedBox(
            width: 48,
            child: Text(result.target.label, style: cellStyle),
          ),
          Expanded(
            child: Text(
              '.${(result.gauge.gaugeInches * 1000).round().toString().padLeft(3, '0')} ${result.gauge.construction == StringConstruction.wound ? 'w' : 'p'}',
              style: cellStyle,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(result.tensionLbf.toStringAsFixed(1), style: cellStyle),
          ),
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: context.instrumentType.status.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelNotice extends StatelessWidget {
  const _ModelNotice({required this.metadata});

  final UnitWeightModelMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.terminal.muted, width: 2),
        ),
      ),
      child: Text(
        '계산 모델 v${metadata.version} · 공식 계산기 20개 스팟체크 최대 오차 3% 미만\n'
        'plain은 강선 밀도로 계산하고 wound는 니켈 라운드와운드 보간값을 사용합니다. 제조사·코어·권선 구조에 따라 실제 장력과 촉감은 달라질 수 있습니다.',
        style: context.instrumentType.caption.copyWith(
          color: context.terminal.muted,
        ),
      ),
    );
  }
}

GaugeSetDefinition _defaultGaugeSet(int stringCount) {
  return switch (stringCount) {
    6 => GaugeSetCatalog.regular10_46,
    7 => GaugeSetCatalog.seven10_59,
    8 => GaugeSetCatalog.eight9_65,
    _ => throw UnsupportedError(
      '$stringCount-string guitars are not supported.',
    ),
  };
}

TuningDefinition _standardReference(int stringCount) {
  if (stringCount == 6) {
    return BuiltInTunings.standardGuitar;
  }
  final lowStrings = switch (stringCount) {
    7 => const [TuningString(stringNumber: 7, midiNote: 35, label: 'B1')],
    8 => const [
      TuningString(stringNumber: 8, midiNote: 30, label: 'F♯1'),
      TuningString(stringNumber: 7, midiNote: 35, label: 'B1'),
    ],
    _ => throw UnsupportedError(
      '$stringCount-string guitars are not supported.',
    ),
  };
  return TuningDefinition(
    id: 'guitar-$stringCount-standard-reference',
    version: 1,
    name: '$stringCount-string Standard',
    strings: [...lowStrings, ...BuiltInTunings.standardGuitar.strings],
  );
}

String _gaugeInputValue(GaugeSetDefinition gaugeSet) {
  return gaugeSet.gaugesLowToHigh.reversed
      .map((gauge) => (gauge.gaugeInches * 1000).round())
      .join('-');
}
