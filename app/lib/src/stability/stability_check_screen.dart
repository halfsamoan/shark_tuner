import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../tuner/live_tuner_engine.dart';
import '../ui/instrument_widgets.dart';
import 'stability_session_tracker.dart';

class StabilityCheckScreen extends StatefulWidget {
  const StabilityCheckScreen({
    super.key,
    required this.tuning,
    required this.engine,
  });

  final TuningDefinition tuning;
  final TunerEngine engine;

  @override
  State<StabilityCheckScreen> createState() => _StabilityCheckScreenState();
}

class _StabilityCheckScreenState extends State<StabilityCheckScreen> {
  late int _selectedIndex;
  late StabilitySessionTracker _tracker;
  late LiveTunerState _liveState;
  late StreamSubscription<LiveTunerState> _subscription;

  TuningString get _selected => widget.tuning.strings[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _tracker = StabilitySessionTracker(
      stringNumber: widget.tuning.strings.first.stringNumber,
    );
    _liveState = widget.engine.current;
    _subscription = widget.engine.states.listen(_handleState);
    widget.engine.setManualTarget(_selected.stringNumber);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    widget.engine.setManualTarget(null);
    super.dispose();
  }

  void _handleState(LiveTunerState state) {
    if (!mounted) {
      return;
    }
    final changed = _tracker.consume(state);
    if (changed || state.status != _liveState.status) {
      setState(() => _liveState = state);
    } else {
      _liveState = state;
    }
  }

  void _selectString(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _tracker = StabilitySessionTracker(
        stringNumber: widget.tuning.strings[index].stringNumber,
      );
    });
    widget.engine.setManualTarget(_selected.stringNumber);
  }

  void _restart() {
    setState(_tracker.reset);
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _tracker.assessment;
    final evidence = assessment.evidence;
    final trusted = evidence.trustedPluckCount;
    final completed = _tracker.completedPluckCount;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '튜닝 안정성', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            const InstrumentSectionLabel(
              '30 sec check  /  같은 줄 반복 측정',
              color: InstrumentColors.accent,
            ),
            const SizedBox(height: 10),
            Text(
              '줄이 맞은 뒤에도 흔들리는지 확인합니다.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '같은 줄을 중간 세기로 한 번 튕기고 약 3초간 울려 주세요. 최소 3회부터 결과를 표시하며, 5회면 반복 측정의 재현성도 확인합니다.',
              style: InstrumentTypeTheme.standard.caption.copyWith(
                color: InstrumentColors.muted,
              ),
            ),
            const SizedBox(height: 22),
            const InstrumentSectionLabel('01  /  측정할 줄'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < widget.tuning.strings.length;
                    index++
                  ) ...[
                    TuningNoteCell(
                      label: widget.tuning.strings[index].label,
                      stringNumber: widget.tuning.strings[index].stringNumber,
                      active: index == _selectedIndex,
                      onTap: () => _selectString(index),
                    ),
                    if (index != widget.tuning.strings.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _CaptureStrip(
              completed: completed,
              trusted: trusted,
              capturing: _tracker.isCapturing,
              complete: _tracker.isComplete,
            ),
            if (_tracker.heardOtherStringNumber case final heard?) ...[
              const SizedBox(height: 10),
              Text(
                '$heard번 줄 소리가 들립니다. ${_selected.stringNumber}번 줄만 튕겨 주세요.',
                style: InstrumentTypeTheme.standard.caption.copyWith(
                  color: InstrumentColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_liveState.status == LiveTunerStatus.permissionDenied ||
                _liveState.status == LiveTunerStatus.unavailable) ...[
              const SizedBox(height: 10),
              Text(
                '마이크 입력을 사용할 수 없습니다. 이전 화면에서 마이크 권한과 입력 상태를 확인해 주세요.',
                style: InstrumentTypeTheme.standard.caption.copyWith(
                  color: InstrumentColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 26),
            const InstrumentSectionLabel('02  /  관측값'),
            const SizedBox(height: 4),
            if (trusted == 0)
              const _EmptyResult(
                text: '아직 신뢰할 수 있는 피킹이 없습니다. 줄을 튕긴 뒤 소리를 끊지 말고 유지해 주세요.',
              )
            else ...[
              DefinitionRow(
                label: '어택 오버슈트',
                value:
                    '${evidence.medianAttackOvershootCents!.toStringAsFixed(1)} cents',
              ),
              DefinitionRow(
                label: '정착 시간',
                value: '${evidence.medianSettleTimeMs!.round()} ms',
              ),
              DefinitionRow(
                label: '울림 중 드리프트',
                value:
                    '${evidence.medianSteadyStateDriftCentsPerSecond!.toStringAsFixed(2)} cents/s',
              ),
              if (evidence.medianInterPluckDriftCents case final drift?)
                DefinitionRow(
                  label: '피킹 간 이동',
                  value: '${drift.toStringAsFixed(1)} cents',
                ),
              if (evidence.normalizedOvershootCoefficientOfVariation
                  case final repeatability?)
                DefinitionRow(
                  label: '5회 재현성',
                  value:
                      'CV ${(repeatability * 100).toStringAsFixed(0)}% ${repeatability <= .3 ? '· 일관됨' : '· 피킹 편차 큼'}',
                  valueColor: repeatability <= .3
                      ? InstrumentColors.accent
                      : InstrumentColors.amber,
                ),
            ],
            const SizedBox(height: 26),
            const InstrumentSectionLabel('03  /  가능한 원인'),
            const SizedBox(height: 8),
            _HypothesisResult(assessment: assessment),
            if (evidence.rejectedPluckCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '신호가 약하거나 불규칙해 제외한 피킹 ${evidence.rejectedPluckCount}회',
                style: InstrumentTypeTheme.standard.status.copyWith(
                  color: InstrumentColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(onPressed: _restart, child: const Text('다시 측정')),
                const Spacer(),
                FilledButton(
                  onPressed: trusted >= 3
                      ? () => Navigator.of(context).pop()
                      : null,
                  child: Text(trusted >= 3 ? '결과 저장하고 닫기' : '3회 측정 필요'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _tracker.isComplete
            ? '측정 완료'
            : _tracker.isCapturing
            ? '울림 분석 중'
            : '피킹 대기',
        detail:
            '${_selected.stringNumber}번 줄 ${_selected.label} │ $completed/5',
        active: _liveState.status == LiveTunerStatus.listening,
      ),
    );
  }
}

class _CaptureStrip extends StatelessWidget {
  const _CaptureStrip({
    required this.completed,
    required this.trusted,
    required this.capturing,
    required this.complete,
  });

  final int completed;
  final int trusted;
  final bool capturing;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: InstrumentColors.line),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < 5; index++) ...[
            Container(
              width: 24,
              height: 6,
              color: index < completed
                  ? InstrumentColors.accent
                  : index == completed && capturing
                  ? InstrumentColors.amber
                  : InstrumentColors.line,
            ),
            if (index != 4) const SizedBox(width: 5),
          ],
          const Spacer(),
          Text(
            complete
                ? '5회 완료'
                : capturing
                ? '소리를 유지하세요'
                : trusted >= 3
                ? '결과 확보 · 5회 권장'
                : '중간 세기로 튕기세요',
            style: InstrumentTypeTheme.standard.status.copyWith(
              color: complete || trusted >= 3
                  ? InstrumentColors.accent
                  : InstrumentColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: InstrumentTypeTheme.standard.caption.copyWith(
          color: InstrumentColors.muted,
        ),
      ),
    );
  }
}

class _HypothesisResult extends StatelessWidget {
  const _HypothesisResult({required this.assessment});

  final StabilityAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final insufficient =
        assessment.status == StabilityAssessmentStatus.insufficientEvidence;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: InstrumentColors.panel,
        border: Border.all(color: InstrumentColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insufficient ? '판단하기 어려움' : '측정 기반 안내',
            style: InstrumentTypeTheme.standard.caption.copyWith(
              color: insufficient
                  ? InstrumentColors.amber
                  : InstrumentColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final hypothesis in assessment.hypotheses)
            Text(
              _hypothesisCopy(hypothesis.kind),
              style: InstrumentTypeTheme.standard.caption.copyWith(
                color: InstrumentColors.text,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '원인은 확정 진단이 아니라 현재 관측값으로 설명 가능한 가능성입니다.',
            style: InstrumentTypeTheme.standard.status.copyWith(
              color: InstrumentColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

String _hypothesisCopy(StabilityHypothesisKind kind) {
  return switch (kind) {
    StabilityHypothesisKind.insufficientEvidence =>
      '신뢰 가능한 피킹이 3회 모이면 가능한 원인을 안내합니다.',
    StabilityHypothesisKind.possibleLightGaugeOrHeavyAttack =>
      '강한 피킹이거나 현재 튜닝에 비해 현 장력이 가벼울 가능성이 있습니다.',
    StabilityHypothesisKind.possibleNutFriction =>
      '튜닝 조작 뒤 피치가 계단처럼 움직였다면 너트 마찰 가능성이 있습니다.',
    StabilityHypothesisKind.possibleNewStringStretch =>
      '피킹할 때마다 낮아지는 경향이 있어 새 현의 늘어남 가능성이 있습니다.',
    StabilityHypothesisKind.noInstabilityObserved =>
      '이번 측정에서는 뚜렷한 튜닝 불안정이 관측되지 않았습니다.',
    StabilityHypothesisKind.indeterminate => '변화는 관측됐지만 현재 값만으로 원인을 좁히기 어렵습니다.',
  };
}
