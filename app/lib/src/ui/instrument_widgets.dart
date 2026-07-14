import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../app/instrument_theme.dart';

class InstrumentHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const InstrumentHeaderBar({
    super.key,
    required this.section,
    this.showBack = false,
    this.actions = const [],
  });

  final String section;
  final bool showBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      backgroundColor: InstrumentColors.header,
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Text(
              section,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InstrumentColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        ...actions,
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
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2).toDouble();
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const BoxDecoration(
          color: InstrumentColors.header,
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
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                detail.toUpperCase(),
                maxLines: textScale > 1.3 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: InstrumentColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
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
  const VerificationBadge({
    super.key,
    required this.status,
    this.showDevelopmentStatus = false,
  });

  final SongVerificationStatus status;
  final bool showDevelopmentStatus;

  @override
  Widget build(BuildContext context) {
    final verified = status == SongVerificationStatus.verified;
    final color = verified ? InstrumentColors.accent : InstrumentColors.amber;
    final label = verified
        ? '검증된 튜닝 ✓'
        : showDevelopmentStatus
        ? 'DEV·사람 검증 필요'
        : '확인 중';
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
    this.completed = false,
    this.onTap,
  });

  final String label;
  final int stringNumber;
  final bool active;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2).toDouble();
    final width = 48 + 12 * (textScale - 1);
    final height = 52 + 32 * (textScale - 1);
    final foreground = active
        ? InstrumentColors.accentInk
        : InstrumentColors.text;
    return Semantics(
      button: onTap != null,
      selected: active,
      label: '$stringNumber번 현 $label${completed ? ', 완료' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: InstrumentMotion.instrument,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: active ? InstrumentColors.accent : InstrumentColors.panel,
            border: Border.all(
              color: active ? InstrumentColors.accent : InstrumentColors.line,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'D2Coding',
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$stringNumber',
                      style: TextStyle(
                        color: active
                            ? InstrumentColors.accentInk
                            : InstrumentColors.muted,
                        fontFamily: 'D2Coding',
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Text(
                    '✓',
                    style: TextStyle(
                      color: active
                          ? InstrumentColors.accentInk
                          : InstrumentColors.lockHold,
                      fontFamily: 'D2Coding',
                      fontSize: 11,
                      height: 1,
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

class IdlePitchTape extends StatelessWidget {
  const IdlePitchTape({super.key});

  @override
  Widget build(BuildContext context) {
    return const PitchTape(status: '신호 대기');
  }
}

class PitchTape extends StatelessWidget {
  const PitchTape({
    super.key,
    required this.status,
    this.cents,
    this.locked = false,
  });

  final String status;
  final double? cents;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: status,
      value: cents == null ? '측정값 없음' : '${cents!.toStringAsFixed(1)} 센트',
      child: RepaintBoundary(
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: locked
                ? InstrumentColors.accent.withValues(alpha: 0.08)
                : InstrumentColors.sunken,
            border: Border.all(
              color: locked ? InstrumentColors.lockHold : InstrumentColors.line,
            ),
          ),
          child: CustomPaint(
            painter: _PitchTapePainter(cents: cents, locked: locked),
          ),
        ),
      ),
    );
  }
}

class _PitchTapePainter extends CustomPainter {
  const _PitchTapePainter({required this.cents, required this.locked});

  final double? cents;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 20.0;
    final tapeWidth = size.width - horizontalPadding * 2;
    double xForCents(double cents) =>
        horizontalPadding + tapeWidth * (cents.clamp(-50, 50) + 50) / 100;
    final greenZone = Paint()
      ..color = InstrumentColors.accent.withValues(alpha: 0.09);
    canvas.drawRect(
      Rect.fromLTRB(xForCents(-5), 8, xForCents(5), size.height - 22),
      greenZone,
    );
    final minor = Paint()
      ..color = InstrumentColors.line
      ..strokeWidth = 1;
    final center = Paint()
      ..color = InstrumentColors.muted
      ..strokeWidth = 2;
    for (var index = 0; index <= 20; index++) {
      final x = horizontalPadding + tapeWidth * index / 20;
      final isMajor = index % 5 == 0;
      final height = isMajor ? 40.0 : 22.0;
      canvas.drawLine(
        Offset(x, 40 - height / 2),
        Offset(x, 40 + height / 2),
        index == 10 ? center : minor,
      );
    }
    _paintLabel(canvas, '−50  ♭', Offset(horizontalPadding, 78));
    _paintLabel(
      canvas,
      '0',
      Offset(size.width / 2, 78),
      alignment: TextAlign.center,
    );
    _paintLabel(
      canvas,
      '♯  +50',
      Offset(size.width - horizontalPadding, 78),
      alignment: TextAlign.right,
    );
    final measuredCents = cents;
    if (measuredCents != null) {
      final x = xForCents(measuredCents);
      final absoluteCents = measuredCents.abs();
      final marker = Paint()
        ..color = locked
            ? InstrumentColors.lockHold
            : absoluteCents <= 5
            ? InstrumentColors.accent
            : absoluteCents <= 15
            ? InstrumentColors.text
            : InstrumentColors.amber
        ..strokeWidth = 3;
      canvas.drawLine(Offset(x, 8), Offset(x, 69), marker);
      final triangle = Path()
        ..moveTo(x - 6, 5)
        ..lineTo(x + 6, 5)
        ..lineTo(x, 13)
        ..close();
      canvas.drawPath(triangle, marker);
      if (absoluteCents > 50) {
        final pointsRight = measuredCents > 0;
        final chevron = Path();
        if (pointsRight) {
          chevron
            ..moveTo(size.width - 12, 32)
            ..lineTo(size.width - 5, 40)
            ..lineTo(size.width - 12, 48);
        } else {
          chevron
            ..moveTo(12, 32)
            ..lineTo(5, 40)
            ..lineTo(12, 48);
        }
        canvas.drawPath(
          chevron,
          Paint()
            ..color = InstrumentColors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintLabel(
    Canvas canvas,
    String label,
    Offset anchor, {
    TextAlign alignment = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: InstrumentColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: alignment,
    )..layout();
    final dx = switch (alignment) {
      TextAlign.center => anchor.dx - painter.width / 2,
      TextAlign.right => anchor.dx - painter.width,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _PitchTapePainter oldDelegate) {
    return oldDelegate.cents != cents || oldDelegate.locked != locked;
  }
}
