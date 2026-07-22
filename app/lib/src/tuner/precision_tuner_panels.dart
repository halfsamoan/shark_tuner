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
  });

  final TuningGuidance guidance;
  final String semanticsLabel;
  final double lockProgress;
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
    final showPegAction =
        guidance.kind == GuidanceSlotKind.direction ||
        guidance.kind == GuidanceSlotKind.settling;
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
                      if (!pegDirection.flipSuggested &&
                          (showPegAction ||
                              pegDirection.needsSetup ||
                              pegDirection.canVerify)) ...[
                        const SizedBox(height: 2),
                        TextButton(
                          key: pegActionKey,
                          onPressed: pegAction,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pegDirection.label,
                                  style: context.instrumentType.status.copyWith(
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
                                  style: context.instrumentType.status.copyWith(
                                    color: context.terminal.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
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
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('그대로 유지'),
                  ),
                  TextButton(
                    key: const Key('accept-peg-direction-flip'),
                    onPressed: onAcceptPegDirectionFlip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
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

class _VisualTuningFeedback extends StatelessWidget {
  const _VisualTuningFeedback({
    required this.guidance,
    required this.locked,
    required this.pegRotation,
    required this.pegNeedsSetup,
    required this.pegDetail,
    this.pegAction,
    this.pegActionKey,
    this.pegActionLabel,
    required this.semanticsLabel,
  });

  final TuningGuidance guidance;
  final bool locked;
  final PegRotationDirection? pegRotation;
  final bool pegNeedsSetup;
  final String pegDetail;
  final VoidCallback? pegAction;
  final Key? pegActionKey;
  final String? pegActionLabel;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? context.terminal.lockHold
        : guidance.coarse
        ? context.terminal.amber
        : guidance.direction == TuningDirection.hold
        ? context.terminal.accent
        : context.terminal.warning;
    final rotation = pegRotation;
    return ThrottledLiveRegion(
      label: semanticsLabel,
      child: Semantics(
        key: const Key('visual-tuning-feedback'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: CustomPaint(
                    painter: _TuningFeedbackSymbolPainter(
                      direction: guidance.direction,
                      locked: locked,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guidance.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.instrumentType.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guidance.instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.instrumentType.status.copyWith(
                        color: context.terminal.textSecondary,
                      ),
                    ),
                    if (!pegNeedsSetup && rotation != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        pegDetail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.instrumentType.status.copyWith(
                          color: context.terminal.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (pegAction != null && pegActionLabel != null)
                TextButton(
                  key: pegActionKey,
                  onPressed: pegAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    pegActionLabel!,
                    style: context.instrumentType.status.copyWith(
                      color: context.terminal.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TuningFeedbackSymbolPainter extends CustomPainter {
  const _TuningFeedbackSymbolPainter({
    required this.direction,
    required this.locked,
    required this.color,
  });

  final TuningDirection direction;
  final bool locked;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    if (direction == TuningDirection.raise ||
        direction == TuningDirection.lower) {
      final pointsUp = direction == TuningDirection.raise;
      final tipY = pointsUp ? center.dy - 15 : center.dy + 15;
      final baseY = pointsUp ? center.dy + 10 : center.dy - 10;
      final triangle = Path()
        ..moveTo(center.dx, tipY)
        ..lineTo(center.dx - 11, baseY)
        ..lineTo(center.dx + 11, baseY)
        ..close();
      canvas.drawPath(triangle, paint);
      return;
    }
    if (!locked) {
      canvas.drawLine(
        Offset(center.dx - 12, center.dy),
        Offset(center.dx + 12, center.dy),
        paint,
      );
      return;
    }
    final check = Path()
      ..moveTo(center.dx - 12, center.dy)
      ..lineTo(center.dx - 3, center.dy + 9)
      ..lineTo(center.dx + 14, center.dy - 11);
    canvas.drawPath(check, paint);
  }

  @override
  bool shouldRepaint(covariant _TuningFeedbackSymbolPainter oldDelegate) {
    return direction != oldDelegate.direction ||
        locked != oldDelegate.locked ||
        color != oldDelegate.color;
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
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('다시 시도'),
              ),
              if (permissionDenied)
                TextButton(
                  key: const Key('open-app-settings'),
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('설정 열기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
