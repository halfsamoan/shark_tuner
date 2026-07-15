part of 'precision_tuner_screen.dart';

class _ReferenceToneControl extends StatelessWidget {
  const _ReferenceToneControl({
    required this.frequencyHz,
    required this.noteLabel,
    required this.playing,
    required this.busy,
    required this.onPressed,
  });

  final double frequencyHz;
  final String noteLabel;
  final bool playing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = playing
        ? context.terminal.accent
        : context.terminal.information;
    final action = playing ? '정지' : '재생';
    return Semantics(
      label: '$noteLabel 레퍼런스 톤 $action',
      button: true,
      enabled: !busy,
      toggled: playing,
      excludeSemantics: true,
      child: OutlinedButton(
        key: const Key('reference-tone-toggle'),
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: color,
          disabledForegroundColor: context.terminal.muted,
          side: BorderSide(
            color: playing
                ? context.terminal.phosphorEdge
                : context.terminal.line,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(InstrumentMetrics.radius2),
            ),
          ),
        ),
        child: Text(
          busy
              ? 'REF 준비 중'
              : playing
              ? '█ REF $noteLabel 정지'
              : 'REF ${frequencyHz.toStringAsFixed(2)} Hz',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.instrumentType.status.copyWith(
            color: busy ? context.terminal.muted : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MicrophonePrimer extends StatelessWidget {
  const _MicrophonePrimer({required this.onEnable});

  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.terminal.canvas.withValues(alpha: 0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: context.terminal.panel,
                border: Border.all(color: context.terminal.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstrumentSectionLabel(
                    '마이크 사용 안내',
                    color: context.terminal.accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '줄 소리를 듣고 음정을 측정해요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '소리는 기기에서만 분석되고 저장되지 않습니다. '
                    '가장 굵은 줄부터 한 번씩 튕기면 다음 줄로 자동 이동합니다.',
                    style: context.instrumentType.caption.copyWith(
                      color: context.terminal.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('enable-microphone'),
                      onPressed: onEnable,
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('안내 확인하고 시작'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
