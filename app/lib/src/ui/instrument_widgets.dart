import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../app/app_preferences.dart';
import '../app/instrument_theme.dart';
import 'instrument_surface.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.width = 28, this.height = 22, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SharkTune',
      image: true,
      child: CustomPaint(
        size: Size(width, height),
        painter: _BrandMarkPainter(color ?? context.terminal.accent),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    final paint = Paint()..color = color;
    final fin = Path()
      ..moveTo(204, 653)
      ..cubicTo(337, 635, 411, 504, 463, 276)
      ..cubicTo(467, 257, 490, 250, 505, 262)
      ..cubicTo(625, 354, 690, 481, 724, 625)
      ..cubicTo(625, 611, 551, 638, 488, 680)
      ..cubicTo(400, 738, 302, 721, 204, 653)
      ..close();
    final wave = Path()
      ..moveTo(112, 697)
      ..cubicTo(220, 628, 313, 630, 411, 696)
      ..cubicTo(506, 760, 598, 760, 696, 696)
      ..cubicTo(784, 637, 860, 636, 912, 666)
      ..lineTo(912, 760)
      ..cubicTo(845, 716, 783, 720, 715, 766)
      ..cubicTo(594, 848, 475, 848, 354, 766)
      ..cubicTo(278, 715, 209, 716, 112, 780)
      ..close();
    canvas.drawPath(fin, paint);
    canvas.drawPath(wave, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

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
      backgroundColor: context.terminal.header,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: context.terminal.line)),
      titleSpacing: showBack ? 4 : 16,
      leading: showBack
          ? IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left_rounded),
            )
          : null,
      title: Row(
        children: [
          const BrandMark(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'SharkTune',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.instrumentType.body.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
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
        decoration: BoxDecoration(
          color: context.terminal.header,
          border: Border(top: BorderSide(color: context.terminal.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? context.terminal.accent
                    : context.terminal.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.toUpperCase(),
                style: context.instrumentType.status.copyWith(
                  color: active
                      ? context.terminal.accent
                      : context.terminal.amber,
                  fontWeight: FontWeight.w600,
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
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.muted,
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
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedValueStyle =
        valueStyle ??
        context.instrumentType.body.copyWith(fontWeight: FontWeight.w500);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.terminal.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: InstrumentSectionLabel(label)),
          Expanded(
            child: Text(
              value,
              style: resolvedValueStyle.copyWith(
                color:
                    valueColor ??
                    resolvedValueStyle.color ??
                    context.terminal.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Instrument-grade frequency text: the live measurement is always distinct
/// from the tuning target, while both values retain a tabular numeric role.
class FrequencyReadout extends StatelessWidget {
  const FrequencyReadout({
    super.key,
    required this.measuredHz,
    required this.targetHz,
  });

  final double? measuredHz;
  final double targetHz;

  @override
  Widget build(BuildContext context) {
    final measured = measuredHz;
    final target = targetHz.toStringAsFixed(2);
    final semanticsLabel = measured == null
        ? '주파수 측정 대기, 목표 $target Hz'
        : '측정 주파수 ${measured.toStringAsFixed(2)} Hz, 목표 $target Hz';
    final labelStyle = context.instrumentType.caption.copyWith(
      color: context.terminal.textSecondary,
    );
    final valueStyle = context.instrumentType.measurement.copyWith(
      color: context.terminal.text,
    );
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: measured == null ? '측정 대기' : '측정 ',
              style: labelStyle,
            ),
            if (measured != null)
              TextSpan(
                text: '${measured.toStringAsFixed(2)} Hz',
                style: valueStyle,
              ),
            TextSpan(text: '  ·  목표 ', style: labelStyle),
            TextSpan(text: '$target Hz', style: valueStyle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// A calm, Adwaita-inspired navigation row rendered with the active
/// instrument tokens. It owns one full-width mobile touch target.
class InstrumentActionRow extends StatelessWidget {
  const InstrumentActionRow({
    super.key,
    required this.rowKey,
    required this.label,
    required this.detail,
    required this.onTap,
    this.trailing,
  });

  final Key rowKey;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $detail',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: rowKey,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.terminal.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.instrumentType.body),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: context.instrumentType.caption.copyWith(
                          color: context.terminal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing ??
                    Text(
                      '›',
                      style: context.instrumentType.subhead.copyWith(
                        color: context.terminal.accent,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A grouped preference row with one switch and a full-row interaction target.
class InstrumentToggleRow extends StatelessWidget {
  const InstrumentToggleRow({
    super.key,
    required this.rowKey,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = '$label, $detail, ${value ? '켜짐' : '꺼짐'}';
    return Semantics(
      label: semanticsLabel,
      toggled: value,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: rowKey,
          onTap: () => onChanged(!value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.only(left: 4, right: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.terminal.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.instrumentType.body),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: context.instrumentType.caption.copyWith(
                          color: context.terminal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum InstrumentStateTone { neutral, warning, danger }

/// Shared loading, empty, and error state treatment. It limits a state to one
/// clear message and one recovery action instead of a dashboard of diagnostics.
class InstrumentStatePanel extends StatelessWidget {
  const InstrumentStatePanel({
    super.key,
    required this.tone,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final InstrumentStateTone tone;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final stateColor = switch (tone) {
      InstrumentStateTone.neutral => context.terminal.information,
      InstrumentStateTone.warning => context.terminal.warning,
      InstrumentStateTone.danger => context.terminal.danger,
    };
    return Semantics(
      label: '$title, $detail',
      child: InstrumentSurface(
        level: InstrumentSurfaceLevel.panel,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.instrumentType.body.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: context.instrumentType.caption.copyWith(
                  color: context.terminal.textSecondary,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton(
                    key: actionKey,
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: stateColor,
                      side: BorderSide(color: stateColor),
                    ),
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
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
    final color = verified ? context.terminal.accent : context.terminal.amber;
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
          style: context.instrumentType.status.copyWith(
            color: color,
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
        ? context.terminal.accentInk
        : context.terminal.text;
    return Semantics(
      button: onTap != null,
      selected: active,
      label: '$stringNumber번 현 $label${completed ? ', 완료' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: shouldReduceMotion(context)
              ? Duration.zero
              : InstrumentMotion.instrument,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: active ? context.terminal.accent : context.terminal.panel,
            border: Border.all(
              color: active ? context.terminal.accent : context.terminal.line,
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
                      style: context.instrumentType.caption.copyWith(
                        color: foreground,
                        fontFamily: 'IBM Plex Mono',
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$stringNumber',
                      style: context.instrumentType.status.copyWith(
                        color: active
                            ? context.terminal.accentInk
                            : context.terminal.muted,
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
                    style: context.instrumentType.status.copyWith(
                      color: active
                          ? context.terminal.accentInk
                          : context.terminal.lockHold,
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
          height: 88,
          decoration: BoxDecoration(
            color: locked
                ? context.terminal.accent.withValues(alpha: 0.08)
                : context.terminal.sunken,
            border: Border.all(
              color: locked ? context.terminal.lockHold : context.terminal.line,
            ),
          ),
          child: CustomPaint(
            painter: _PitchTapePainter(
              cents: cents,
              locked: locked,
              terminal: context.terminal,
              type: context.instrumentType,
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchTapePainter extends CustomPainter {
  const _PitchTapePainter({
    required this.cents,
    required this.locked,
    required this.terminal,
    required this.type,
  });

  final double? cents;
  final bool locked;
  final TerminalTheme terminal;
  final InstrumentTypeTheme type;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 20.0;
    final tapeWidth = size.width - horizontalPadding * 2;
    double xForCents(double cents) =>
        horizontalPadding + tapeWidth * (cents.clamp(-50, 50) + 50) / 100;
    final greenZone = Paint()..color = terminal.accent.withValues(alpha: 0.09);
    canvas.drawRect(
      Rect.fromLTRB(xForCents(-5), 8, xForCents(5), size.height - 22),
      greenZone,
    );
    final minor = Paint()
      ..color = terminal.line
      ..strokeWidth = 1;
    final center = Paint()
      ..color = terminal.muted
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
            ? terminal.lockHold
            : absoluteCents <= 5
            ? terminal.accent
            : absoluteCents <= 15
            ? terminal.text
            : terminal.amber
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
            ..color = terminal.amber
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
        style: type.status.copyWith(
          color: terminal.muted,
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
    return oldDelegate.cents != cents ||
        oldDelegate.locked != locked ||
        oldDelegate.terminal != terminal ||
        oldDelegate.type != type;
  }
}
