part of 'precision_tuner_screen.dart';

class _TunerSkinFrame extends StatelessWidget {
  const _TunerSkinFrame({required this.skin, required this.child});

  final TunerSkin skin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (skin == TunerSkin.standard) {
      return child;
    }
    return Container(
      key: const Key('clipping-tuner-skin'),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.terminal.danger, width: 4),
          top: BorderSide(color: context.terminal.accent, width: 2),
          right: BorderSide(color: context.terminal.line),
          bottom: BorderSide(color: context.terminal.line),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 30),
            color: context.terminal.header,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Text(
                  'CLIP//LIVE_00',
                  style: context.instrumentType.status.copyWith(
                    color: context.terminal.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ERR//CH-01  OVERDRIVE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.instrumentType.status.copyWith(
                      color: context.terminal.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            key: const Key('clipping-signal-tear'),
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 4,
                  width: 116,
                  height: 5,
                  child: ColoredBox(color: context.terminal.phosphorEdge),
                ),
                Positioned(
                  left: 34,
                  top: 7,
                  width: 148,
                  height: 5,
                  child: ColoredBox(color: context.terminal.accent),
                ),
                Positioned(
                  right: -8,
                  top: 2,
                  child: Transform.rotate(
                    angle: -.035,
                    child: Container(
                      color: context.terminal.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        'SIGNAL TEAR / 02',
                        style: context.instrumentType.status.copyWith(
                          color: context.terminal.raised,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(8), child: child),
        ],
      ),
    );
  }
}

class _GuidancePanel extends StatelessWidget {
  const _GuidancePanel({
    required this.guidance,
    required this.semanticsLabel,
    required this.lockProgress,
    required this.pegDirection,
    required this.onConfigurePegGuidance,
    required this.onVerifyPegDirection,
    required this.onAcceptPegDirectionFlip,
    required this.onDismissPegDirectionFlip,
    this.offsetLabel,
  });

  final TuningGuidance guidance;
  final String semanticsLabel;
  final double lockProgress;
  final String? offsetLabel;
  final _PegDirectionPresentation pegDirection;
  final VoidCallback onConfigurePegGuidance;
  final VoidCallback onVerifyPegDirection;
  final VoidCallback onAcceptPegDirectionFlip;
  final VoidCallback onDismissPegDirectionFlip;

  @override
  Widget build(BuildContext context) {
    final completed =
        guidance.direction == TuningDirection.hold &&
        guidance.headline.contains('완료');
    final color = completed
        ? context.terminal.accent
        : guidance.coarse
        ? context.terminal.amber
        : context.terminal.text;
    final VoidCallback? pegAction = pegDirection.pending
        ? null
        : pegDirection.needsSetup
        ? onConfigurePegGuidance
        : pegDirection.canVerify
        ? onVerifyPegDirection
        : onConfigurePegGuidance;
    final pegActionKey = pegDirection.pending
        ? null
        : pegDirection.needsSetup
        ? const Key('configure-peg-guidance')
        : pegDirection.canVerify
        ? const Key('verify-peg-direction')
        : const Key('configure-peg-guidance');
    final pegActionLabel = pegDirection.needsSetup
        ? '설정'
        : pegDirection.canVerify
        ? pegDirection.classicalCalibration
              ? '확인 시작'
              : '방향 확인'
        : '기타 설정';
    return ThrottledLiveRegion(
      label: semanticsLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          color: completed
              ? context.terminal.lockHold.withValues(alpha: 0.08)
              : context.terminal.panel,
          border: Border.all(
            color: completed
                ? context.terminal.lockHold
                : context.terminal.line,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    guidance.leadingSymbol,
                    textAlign: TextAlign.center,
                    style: context.instrumentType.subhead.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guidance.headline,
                        style: context.instrumentType.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guidance.instruction,
                        style: context.instrumentType.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!pegDirection.flipSuggested) ...[
                        const SizedBox(height: 2),
                        Semantics(
                          button: pegAction != null,
                          label: '$pegActionLabel. ${pegDirection.label}',
                          child: InkWell(
                            key: pegActionKey,
                            onTap: pegAction,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pegDirection.label,
                                      style: context.instrumentType.status
                                          .copyWith(
                                            color: pegDirection.pending
                                                ? context.terminal.amber
                                                : context.terminal.muted,
                                            fontWeight: pegDirection.pending
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (pegAction != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      pegActionLabel,
                                      style: context.instrumentType.status
                                          .copyWith(
                                            color: context.terminal.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (lockProgress > 0 && lockProgress < 1) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: lockProgress,
                minHeight: 3,
                color: context.terminal.accent,
                backgroundColor: context.terminal.line,
              ),
            ],
            if (offsetLabel != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  offsetLabel!,
                  style: context.instrumentType.status.copyWith(
                    color: context.terminal.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (pegDirection.flipSuggested) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: context.terminal.line),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '방향 안내를 멈췄어요',
                  style: context.instrumentType.caption.copyWith(
                    color: context.terminal.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '안내와 반대로 두 번 움직였습니다. 이 페그만 방향을 바꿀까요?',
                  style: context.instrumentType.caption.copyWith(
                    color: context.terminal.muted,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDismissPegDirectionFlip,
                    child: const Text('그대로 유지'),
                  ),
                  TextButton(
                    key: const Key('accept-peg-direction-flip'),
                    onPressed: onAcceptPegDirectionFlip,
                    child: const Text('이 페그만 반대로'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TuneCompleteSheet extends StatelessWidget {
  const _TuneCompleteSheet({
    required this.tuning,
    required this.elapsed,
    required this.compatibleSongs,
    required this.onStabilityCheck,
  });

  final TuningDefinition tuning;
  final Duration elapsed;
  final Future<List<SongTuningMatch>> compatibleSongs;
  final VoidCallback onStabilityCheck;

  @override
  Widget build(BuildContext context) {
    final seconds = elapsed.inSeconds;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✓',
              key: Key('tune-complete-glyph'),
              style: context.instrumentType.title.copyWith(
                color: context.terminal.lockFlood,
                fontFamily: 'IBM Plex Mono',
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${tuning.strings.length}현 모두 완료!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${tuning.name} · $seconds초',
              style: TextStyle(color: context.terminal.muted),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<SongTuningMatch>>(
              future: compatibleSongs,
              builder: (context, snapshot) {
                final count = snapshot.data?.length;
                return Text(
                  count == null ? '연주 가능한 곡 확인 중' : '이 튜닝으로 연주 가능한 곡 $count개',
                  style: context.instrumentType.caption.copyWith(
                    color: context.terminal.accent,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('완료'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('open-stability-check'),
                    onPressed: onStabilityCheck,
                    child: const Text('30초 안정성 검사'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
  final SongTuningRecord? song;
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
            InstrumentSectionLabel('DEV·실기기 진단', color: context.terminal.amber),
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
                  ? context.terminal.text
                  : state.pluckToDisplayP95Latency!.inMilliseconds <= 150
                  ? context.terminal.accent
                  : context.terminal.danger,
            ),
            DefinitionRow(
              label: 'DEV·튜닝 진행',
              value: _tuneUpProgressLabel(progress),
            ),
            DefinitionRow(
              label: 'DEV·곡 설정',
              value:
                  '${tuning.id}@${tuning.version} · ${_offsetLabel(tuning.centsOffset)} · capo ${song?.capoFret ?? 0}',
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
    required this.onOpenSettings,
  });

  final bool permissionDenied;
  final Future<void> Function() onRetry;
  final AppSettingsLauncher onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: context.terminal.panel,
        border: Border.all(color: context.terminal.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            permissionDenied
                ? '설정에서 마이크를 허용해 주세요.'
                : '사용 가능한 마이크 입력을 찾지 못했습니다.',
            style: context.instrumentType.status.copyWith(
              color: context.terminal.danger,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
              if (permissionDenied)
                TextButton(
                  key: const Key('open-app-settings'),
                  onPressed: onOpenSettings,
                  child: const Text('설정 열기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatMeasuredCents(double? cents, {required bool coarse}) {
  if (cents == null) {
    return '—';
  }
  if (coarse) {
    return cents > 0 ? '▼ 50¢+' : '▲ 50¢+';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(1)}¢';
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

String _rotationDirectionLabel(PegRotationDirection direction) {
  return switch (direction) {
    PegRotationDirection.clockwise => '↻ 시계방향',
    PegRotationDirection.counterClockwise => '↺ 반시계방향',
  };
}

String _pegProfileLabel(InstrumentPegProfile profile) {
  final layout = switch (profile.layout) {
    HeadstockLayout.split =>
      profile.stringCount == 6
          ? '3+3'
          : '${profile.bassSideStringCount}+${profile.stringCount - profile.bassSideStringCount}',
    HeadstockLayout.inline => '${profile.stringCount}인라인',
    HeadstockLayout.classicalSplit => '클래식 슬롯형',
  };
  final hand = profile.handedness == InstrumentHandedness.right ? '오른손' : '왼손';
  final reverse = profile.orientation == HeadstockOrientation.reversed
      ? ' · 리버스'
      : '';
  return '$layout · $hand$reverse';
}
