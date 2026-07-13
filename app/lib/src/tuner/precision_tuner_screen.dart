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
  late final Future<List<SongTuningMatch>> _compatibleSongs;
  late LiveTunerState _liveState;

  @override
  void initState() {
    super.initState();
    _engine = widget.tunerEngineFactory();
    _liveState = _engine.current;
    _engineSubscription = _engine.states.listen(_handleEngineState);
    _compatibleSongs = widget.catalog.findPlayableWith(
      widget.match.tuning,
      includeUnverified: widget.includeUnverifiedSongs,
    );
    unawaited(_engine.start(widget.match.tuning));
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final song = widget.match.song;
    final tuning = widget.match.tuning;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '정밀 튜너', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Container(
              height: 34,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: InstrumentColors.chrome,
                border: Border.all(color: InstrumentColors.line),
              ),
              child: Text(
                '${song.title.toUpperCase()}  /  ${tuning.name.toUpperCase()}  /  ${_offsetLabel(tuning.centsOffset)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InstrumentColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 34),
            Text(
              'STRING ${_selected.stringNumber}  ·  ${_manualTarget ? 'MANUAL' : 'AUTO'} TARGET',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _liveState.target?.label ?? _selected.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: InstrumentColors.text,
                fontSize: 62,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatMeasuredCents(_liveState.cents),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _liveState.locked
                    ? InstrumentColors.accent
                    : InstrumentColors.text,
                fontSize: 30,
                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 22),
            PitchTape(
              cents: _liveState.cents,
              locked: _liveState.locked,
              status: _tapeStatus(_liveState),
            ),
            const SizedBox(height: 18),
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
                Text(
                  'TARGET ${_targetHz.toStringAsFixed(2)} Hz',
                  style: const TextStyle(
                    color: InstrumentColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            DefinitionRow(label: '입력', value: _inputDescription(_liveState)),
            DefinitionRow(
              label: '분석',
              value:
                  '${_liveState.actualSampleRate ?? 48000} Hz · '
                  '${_liveState.windowSamples ?? (_selected.midiNote < 40 ? 8192 : 4096)} samples',
            ),
            DefinitionRow(
              label: 'DSP',
              value: _liveState.processingDuration == null
                  ? 'isolate 준비'
                  : '${(_liveState.processingDuration!.inMicroseconds / 1000).toStringAsFixed(2)} ms · isolate',
            ),
            DefinitionRow(
              label: '곡 오프셋',
              value: _offsetLabel(tuning.centsOffset),
              valueColor: tuning.centsOffset == 0
                  ? InstrumentColors.text
                  : InstrumentColors.accent,
            ),
            DefinitionRow(
              label: '카포',
              value: song.capoFret == 0
                  ? '튜닝 후 장착 없음'
                  : '튜닝 후 ${song.capoFret} 프렛에 장착',
            ),
            const SizedBox(height: 18),
            if (_liveState.status == LiveTunerStatus.permissionDenied ||
                _liveState.status == LiveTunerStatus.unavailable) ...[
              _InputErrorNotice(
                permissionDenied:
                    _liveState.status == LiveTunerStatus.permissionDenied,
                onRetry: _retryInput,
              ),
              const SizedBox(height: 18),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<SongTuningMatch>>(
              future: _compatibleSongs,
              builder: (context, snapshot) {
                final count = snapshot.data?.length;
                if (count == null) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '이 설정으로 바로 연주 가능한 곡 $count개',
                  style: const TextStyle(
                    color: InstrumentColors.muted,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _statusBarState(_liveState),
        detail: _statusBarDetail(_liveState),
        active: _liveState.status == LiveTunerStatus.listening,
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
    LiveTunerStatus.idle => 'DSP idle',
    LiveTunerStatus.probingInput => 'input probe',
    LiveTunerStatus.permissionDenied => 'permission required',
    LiveTunerStatus.unavailable => 'input unavailable',
    LiveTunerStatus.listening when state.locked => 'in tune',
    LiveTunerStatus.listening => 'listening',
  };
}

String _statusBarDetail(LiveTunerState state) {
  final sampleRate = state.actualSampleRate;
  final source = state.selectedSource?.name;
  if (sampleRate == null || source == null) {
    return 'mic · MPM';
  }
  return '${sampleRate ~/ 1000} kHz · $source';
}

String _offsetLabel(double cents) {
  if (cents == 0) {
    return '0 cents';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(cents == cents.roundToDouble() ? 0 : 1)} cents';
}
