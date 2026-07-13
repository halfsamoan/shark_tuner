import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../app/instrument_theme.dart';

class InstrumentHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const InstrumentHeaderBar({
    super.key,
    required this.section,
    this.showBack = false,
  });

  final String section;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      backgroundColor: InstrumentColors.chrome,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: InstrumentColors.line)),
      titleSpacing: showBack ? 4 : 16,
      leading: showBack
          ? IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left_rounded),
            )
          : null,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: InstrumentColors.accent,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'toauner',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        Center(
          child: Text(
            section,
            style: const TextStyle(
              color: InstrumentColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

class InstrumentStatusBar extends StatelessWidget {
  const InstrumentStatusBar({
    super.key,
    required this.state,
    required this.detail,
    this.active = true,
  });

  final String state;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: InstrumentColors.chrome,
          border: Border(top: BorderSide(color: InstrumentColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? InstrumentColors.accent
                    : InstrumentColors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.toUpperCase(),
                style: TextStyle(
                  color: active
                      ? InstrumentColors.accent
                      : InstrumentColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(
              detail.toUpperCase(),
              style: const TextStyle(
                color: InstrumentColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstrumentSectionLabel extends StatelessWidget {
  const InstrumentSectionLabel(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

class DefinitionRow extends StatelessWidget {
  const DefinitionRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: InstrumentColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: InstrumentSectionLabel(label)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? InstrumentColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.status});

  final SongVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final verified = status == SongVerificationStatus.verified;
    final color = verified ? InstrumentColors.accent : InstrumentColors.amber;
    final label = verified ? '출처 검증 완료' : '사람 검증 필요';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class TuningNoteCell extends StatelessWidget {
  const TuningNoteCell({
    super.key,
    required this.label,
    required this.stringNumber,
    this.active = false,
    this.onTap,
  });

  final String label;
  final int stringNumber;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? InstrumentColors.accentInk
        : InstrumentColors.text;
    return Semantics(
      button: onTap != null,
      selected: active,
      label: '$stringNumber번 현 $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 52,
          decoration: BoxDecoration(
            color: active ? InstrumentColors.accent : InstrumentColors.panel,
            border: Border.all(
              color: active ? InstrumentColors.accent : InstrumentColors.line,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$stringNumber',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF32420E)
                      : InstrumentColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IdlePitchTape extends StatelessWidget {
  const IdlePitchTape({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: InstrumentColors.chrome,
        border: Border.all(color: InstrumentColors.line),
      ),
      child: CustomPaint(
        painter: const _PitchTapePainter(),
        child: const Center(
          child: Text(
            '신호 대기',
            style: TextStyle(
              color: InstrumentColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchTapePainter extends CustomPainter {
  const _PitchTapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = InstrumentColors.line
      ..strokeWidth = 1;
    final center = Paint()
      ..color = InstrumentColors.accent
      ..strokeWidth = 2;
    for (var index = 0; index <= 20; index++) {
      final x = 16 + (size.width - 32) * index / 20;
      final isMajor = index % 5 == 0;
      final height = isMajor ? 34.0 : 18.0;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        index == 10 ? center : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchTapePainter oldDelegate) => false;
}
