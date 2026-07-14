import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';
import '../ui/throttled_live_region.dart';
import 'live_tuner_engine.dart';

class StageModeScreen extends StatefulWidget {
  const StageModeScreen({
    super.key,
    required this.engine,
    required this.tuning,
    required this.initialTarget,
  });

  final TunerEngine engine;
  final TuningDefinition tuning;
  final TuningString initialTarget;

  @override
  State<StageModeScreen> createState() => _StageModeScreenState();
}

class _StageModeScreenState extends State<StageModeScreen> {
  late LiveTunerState _state;
  late TuningString _target;
  late final StreamSubscription<LiveTunerState> _subscription;

  @override
  void initState() {
    super.initState();
    _state = widget.engine.current;
    _target = _state.target ?? widget.initialTarget;
    _subscription = widget.engine.states.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _target = state.target ?? _target;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _StagePresentation.from(_state, _target);
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '무대', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: InstrumentMetrics.space12,
                  vertical: InstrumentMetrics.space8,
                ),
                decoration: const BoxDecoration(
                  color: InstrumentColors.header,
                  border: Border.fromBorderSide(
                    BorderSide(color: InstrumentColors.line),
                  ),
                ),
                child: Text(
                  '${widget.tuning.name} │ A4 ${widget.tuning.referenceA4Hz.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InstrumentTypeTheme.standard.status.copyWith(
                    color: InstrumentColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ThrottledLiveRegion(
                  label: presentation.spokenLabel,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _target.label,
                          key: const Key('stage-note'),
                          maxLines: 1,
                          style: InstrumentTypeTheme.standard.centsHero
                              .copyWith(color: presentation.color),
                        ),
                        const SizedBox(height: InstrumentMetrics.space8),
                        Text(
                          presentation.centsLabel,
                          style: InstrumentTypeTheme.standard.title.copyWith(
                            color: presentation.color,
                            fontFamily: 'D2Coding',
                          ),
                        ),
                        const SizedBox(height: InstrumentMetrics.space12),
                        Text(
                          presentation.actionLabel,
                          textAlign: TextAlign.center,
                          style: InstrumentTypeTheme.standard.subhead.copyWith(
                            color: presentation.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PitchTape(
                cents: _state.cents,
                locked: _state.locked,
                status: _state.status == LiveTunerStatus.listening
                    ? '듣는 중'
                    : '줄을 튕겨 주세요',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _state.locked
            ? '인튠'
            : _state.status == LiveTunerStatus.listening
            ? '듣는 중'
            : '대기',
        detail: '무대 모드 │ ${_target.stringNumber}번 줄',
        active: _state.status == LiveTunerStatus.listening,
      ),
    );
  }
}

final class _StagePresentation {
  const _StagePresentation({
    required this.centsLabel,
    required this.actionLabel,
    required this.spokenLabel,
    required this.color,
  });

  factory _StagePresentation.from(LiveTunerState state, TuningString target) {
    final cents = state.cents;
    if (cents == null || !cents.isFinite) {
      return _StagePresentation(
        centsLabel: '—¢',
        actionLabel: '줄을 한 번 튕겨 주세요',
        spokenLabel: '${target.stringNumber}번 줄 ${target.label}, 줄을 한 번 튕겨 주세요',
        color: InstrumentColors.text,
      );
    }
    final rounded = cents.round();
    final centsLabel = '${rounded > 0 ? '+' : ''}$rounded¢';
    if (state.locked) {
      return _StagePresentation(
        centsLabel: centsLabel,
        actionLabel: '✓ 인튠',
        spokenLabel: '${target.stringNumber}번 줄 ${target.label}, 인튠',
        color: InstrumentColors.lockHold,
      );
    }
    if (cents > 2) {
      return _StagePresentation(
        centsLabel: centsLabel,
        actionLabel: '▼ 낮추세요',
        spokenLabel:
            '${target.stringNumber}번 줄 ${target.label}, ${cents.abs().round()}센트 높음, 낮추세요',
        color: InstrumentColors.amber,
      );
    }
    if (cents < -2) {
      return _StagePresentation(
        centsLabel: centsLabel,
        actionLabel: '▲ 올리세요',
        spokenLabel:
            '${target.stringNumber}번 줄 ${target.label}, ${cents.abs().round()}센트 낮음, 올리세요',
        color: InstrumentColors.amber,
      );
    }
    return _StagePresentation(
      centsLabel: centsLabel,
      actionLabel: '… 거의 맞았어요',
      spokenLabel:
          '${target.stringNumber}번 줄 ${target.label}, ${cents.abs().round()}센트, 거의 맞았어요',
      color: InstrumentColors.accent,
    );
  }

  final String centsLabel;
  final String actionLabel;
  final String spokenLabel;
  final Color color;
}
