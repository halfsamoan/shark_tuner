import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';
import 'live_tuner_engine.dart';

class PrecisionTunerScreen extends StatefulWidget {
  const PrecisionTunerScreen({
    super.key,
    required this.match,
    required this.catalog,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
  });

  final SongTuningMatch match;
  final SongCatalog catalog;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;

  @override
  State<PrecisionTunerScreen> createState() => _PrecisionTunerScreenState();
}

class _PrecisionTunerScreenState extends State<PrecisionTunerScreen> {
  var _selectedIndex = 0;
  var _manualTarget = false;
  late final TunerEngine _engine;
  late final StreamSubscription<LiveTunerState> _engineSubscription;
  late final Stopwatch _tuneUpStopwatch;
  late final TuneUpProgressTracker _tuneUpTracker;
  late LiveTunerState _liveState;

  @override
  void initState() {
    super.initState();
    _engine = widget.tunerEngineFactory();
    _liveState = _engine.current;
    _tuneUpStopwatch = Stopwatch()..start();
    _tuneUpTracker = TuneUpProgressTracker(
      expectedStringNumbers: widget.match.tuning.strings.map(
        (string) => string.stringNumber,
      ),
    );
    _engineSubscription = _engine.states.listen(_handleEngineState);
    unawaited(_engine.start(widget.match.tuning));
  }

  @override
  void dispose() {
    _tuneUpStopwatch.stop();
    unawaited(_engineSubscription.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  TuningString get _selected => widget.match.tuning.strings[_selectedIndex];

  double get _targetHz => _selected.targetFrequencyHz(
    referenceA4Hz: widget.match.tuning.referenceA4Hz,
    centsOffset: widget.match.tuning.centsOffset,
  );

  void _handleEngineState(LiveTunerState state) {
    if (!mounted) {
      return;
    }
    final detectedTarget = state.target;
    if (state.locked && detectedTarget != null) {
      _tuneUpTracker.recordLock(
        stringNumber: detectedTarget.stringNumber,
        elapsed: _tuneUpStopwatch.elapsed,
      );
    }
    setState(() {
      _liveState = state;
      if (!_manualTarget && detectedTarget != null) {
        final index = widget.match.tuning.strings.indexWhere(
          (target) => target.stringNumber == detectedTarget.stringNumber,
        );
        if (index >= 0) {
          _selectedIndex = index;
        }
      }
    });
  }

  void _toggleTarget(int index) {
    setState(() {
      if (_manualTarget && _selectedIndex == index) {
        _manualTarget = false;
        _engine.setManualTarget(null);
      } else {
        _selectedIndex = index;
        _manualTarget = true;
        _engine.setManualTarget(_selected.stringNumber);
      }
    });
  }

  Future<void> _retryInput() async {
    await _engine.stop();
    if (!mounted) {
      return;
    }
    await _engine.start(widget.match.tuning);
  }

  void _showDiagnostics() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: InstrumentColors.chrome,
      isScrollControlled: true,
      builder: (context) => _DiagnosticsSheet(
        state: _liveState,
        tuning: widget.match.tuning,
        song: widget.match.song,
        progress: _tuneUpTracker.state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.match.song;
    final tuning = widget.match.tuning;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '정밀 튜너', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              Container(
                height: 34,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: InstrumentColors.chrome,
                  border: Border.all(color: InstrumentColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${song.title.toUpperCase()}  /  ${tuning.name.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: InstrumentColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.includeUnverifiedSongs)
                      TextButton(
                        key: const Key('dev-diagnostics'),
                        onPressed: _showDiagnostics,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'DEV·진단',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < tuning.strings.length;
                      index++
                    ) ...[
                      TuningNoteCell(
                        label: tuning.strings[index].label,
                        stringNumber: tuning.strings[index].stringNumber,
                        active: _selectedIndex == index,
                        onTap: () => _toggleTarget(index),
                      ),
                      if (index != tuning.strings.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_liveState.target?.label ?? _selected.label} · ${_selected.stringNumber}번 줄 · ${_manualTarget ? '직접 선택' : '자동 인식'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              Text(
                _formatMeasuredCents(_liveState.cents),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _liveState.locked
                      ? InstrumentColors.accent
                      : InstrumentColors.text,
                  fontSize: 62,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              Text(
                _signalDescription(_liveState),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _liveState.locked
                      ? InstrumentColors.accent
                      : InstrumentColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              PitchTape(
                cents: _liveState.cents,
                locked: _liveState.locked,
                status: _tapeStatus(_liveState),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _liveState.frequencyHz == null
                        ? '— Hz'
                        : '${_liveState.frequencyHz!.toStringAsFixed(2)} Hz',
                    style: const TextStyle(
                      color: InstrumentColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '목표 ${_targetHz.toStringAsFixed(2)} Hz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: InstrumentColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_liveState.status == LiveTunerStatus.permissionDenied ||
                  _liveState.status == LiveTunerStatus.unavailable) ...[
                _InputErrorNotice(
                  permissionDenied:
                      _liveState.status == LiveTunerStatus.permissionDenied,
                  onRetry: _retryInput,
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: InstrumentColors.panel,
                  border: Border.all(color: InstrumentColors.line),
                ),
                child: Text(
                  tuning.centsOffset == 0
                      ? '현을 한 번 튕기면 측정을 시작합니다.'
                      : '곡 기준 ${_offsetLabel(tuning.centsOffset)} 적용',
                  style: TextStyle(
                    color: tuning.centsOffset == 0
                        ? InstrumentColors.muted
                        : InstrumentColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '튜닝 진행 ${_tuneUpTracker.state.lockedStringCount}/${_tuneUpTracker.state.expectedStringCount}',
                style: TextStyle(
                  color: _tuneUpTracker.state.isComplete
                      ? InstrumentColors.accent
                      : InstrumentColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _statusBarState(_liveState),
        detail:
            '${tuning.name.toUpperCase()} │ A4 ${tuning.referenceA4Hz.toStringAsFixed(0)}',
        active: _liveState.status == LiveTunerStatus.listening,
      ),
    );
  }
}

class _DiagnosticsSheet extends StatelessWidget {
  const _DiagnosticsSheet({
    required this.state,
    required this.tuning,
    required this.song,
    required this.progress,
  });

  final LiveTunerState state;
  final TuningDefinition tuning;
  final SongTuningRecord song;
  final TuneUpProgressState progress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InstrumentSectionLabel(
              'DEV·실기기 진단',
              color: InstrumentColors.amber,
            ),
            const SizedBox(height: 10),
            DefinitionRow(label: 'DEV·입력', value: _inputDescription(state)),
            DefinitionRow(
              label: 'DEV·분석',
              value:
                  '${state.actualSampleRate ?? 48000} Hz · '
                  '${state.windowSamples ?? 4096} samples',
            ),
            DefinitionRow(
              label: 'DEV·DSP',
              value: state.processingDuration == null
                  ? 'isolate 준비'
                  : '${(state.processingDuration!.inMicroseconds / 1000).toStringAsFixed(2)} ms · isolate',
            ),
            DefinitionRow(
              label: 'DEV·첫 응답',
              value: state.pluckToFirstValidLatency == null
                  ? '픽 어택 대기'
                  : '${(state.pluckToFirstValidLatency!.inMicroseconds / 1000).toStringAsFixed(1)} ms · PCM 기준',
            ),
            DefinitionRow(
              label: 'DEV·응답 p95',
              value: state.pluckToDisplayP95Latency == null
                  ? '표본 대기 · 매번 현을 뮤트한 뒤 피킹'
                  : '${(state.pluckToDisplayP95Latency!.inMicroseconds / 1000).toStringAsFixed(1)} ms · n=${state.pluckLatencySampleCount}',
              valueColor: state.pluckToDisplayP95Latency == null
                  ? InstrumentColors.text
                  : state.pluckToDisplayP95Latency!.inMilliseconds <= 150
                  ? InstrumentColors.accent
                  : InstrumentColors.danger,
            ),
            DefinitionRow(
              label: 'DEV·튜닝 진행',
              value: _tuneUpProgressLabel(progress),
            ),
            DefinitionRow(
              label: 'DEV·곡 설정',
              value:
                  '${tuning.id}@${tuning.version} · ${_offsetLabel(tuning.centsOffset)} · capo ${song.capoFret}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InputErrorNotice extends StatelessWidget {
  const _InputErrorNotice({
    required this.permissionDenied,
    required this.onRetry,
  });

  final bool permissionDenied;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: InstrumentColors.panel,
        border: Border.all(color: InstrumentColors.danger),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              permissionDenied
                  ? '마이크 권한을 허용한 뒤 다시 시도하세요.'
                  : '사용 가능한 마이크 입력을 찾지 못했습니다.',
              style: const TextStyle(
                color: InstrumentColors.danger,
                fontSize: 11,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

String _formatMeasuredCents(double? cents) {
  if (cents == null) {
    return '—';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(1)}';
}

String _signalDescription(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.idle => 'cents · 입력 준비',
    LiveTunerStatus.probingInput => 'cents · 입력 확인 중',
    LiveTunerStatus.permissionDenied => 'cents · 마이크 권한 필요',
    LiveTunerStatus.unavailable => 'cents · 입력 사용 불가',
    LiveTunerStatus.listening when state.locked => 'cents · 인튠 잠금',
    LiveTunerStatus.listening when state.frequencyHz != null => 'cents · 안정화됨',
    LiveTunerStatus.listening => 'cents · 신호 확인 중',
  };
}

String _tapeStatus(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.probingInput => '현을 한 번 튕기세요',
    LiveTunerStatus.permissionDenied => '마이크 권한 필요',
    LiveTunerStatus.unavailable => '입력 확인 필요',
    LiveTunerStatus.listening when state.locked => 'IN TUNE',
    LiveTunerStatus.listening when state.frequencyHz != null => '측정 중',
    _ => '신호 대기',
  };
}

String _inputDescription(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.idle => '대기',
    LiveTunerStatus.probingInput => 'UNPROCESSED 확인 중 · 지금 튕기세요',
    LiveTunerStatus.permissionDenied => '권한 거부됨',
    LiveTunerStatus.unavailable => '입력 없음',
    LiveTunerStatus.listening => switch (state.selectedSource?.name) {
      'unprocessed' => 'UNPROCESSED · 처리 없음',
      'voiceRecognition' => 'VOICE_RECOGNITION · 폴백',
      _ => '마이크 · 소스 확인 중',
    },
  };
}

String _statusBarState(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.idle => '준비 중',
    LiveTunerStatus.probingInput => '입력 확인 중',
    LiveTunerStatus.permissionDenied => '마이크 권한 필요',
    LiveTunerStatus.unavailable => '마이크 확인 필요',
    LiveTunerStatus.listening when state.locked => '인튠',
    LiveTunerStatus.listening => '듣는 중',
  };
}

String _offsetLabel(double cents) {
  if (cents == 0) {
    return '0 cents';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(cents == cents.roundToDouble() ? 0 : 1)} cents';
}

String _tuneUpProgressLabel(TuneUpProgressState state) {
  final elapsed = state.elapsed;
  final minutes = elapsed.inMinutes;
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  final progress = '${state.lockedStringCount}/${state.expectedStringCount}';
  return state.isComplete
      ? '$progress · 완료 ${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$progress · ${minutes.toString().padLeft(2, '0')}:$seconds';
}
