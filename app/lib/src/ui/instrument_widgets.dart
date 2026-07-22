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
    this.showBrand = true,
    this.hidden = false,
    this.actions = const [],
  });

  final String section;
  final bool showBack;
  final bool showBrand;
  final bool hidden;
  final List<Widget> actions;

  @override
  Size get preferredSize => hidden ? Size.zero : const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return const SizedBox.shrink();
    }
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
      title: showBrand
          ? Row(
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
            )
          : Text(
              section,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.instrumentType.body.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
      actions: [
        if (showBrand)
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
      label,
      style: context.instrumentType.status.copyWith(
        color: color ?? context.terminal.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
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
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '목표 ', style: labelStyle),
                TextSpan(text: '$target Hz', style: valueStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Explicit presentation states for the live measurement focal point.
///
/// These states are intentionally UI-only: pitch detection and tuning-domain
/// contracts continue to expose their existing result types.
enum CalibrationSpineState {
  waiting,
  coarse,
  adjusting,
  near,
  locked,
  referenceTone,
}

/// The main live-tuner reading. It joins the cent value, target note, measured
/// frequency and calibrated pitch tape into one instrument-like composition so
/// the player does not have to scan competing cards.
class CalibrationSpine extends StatelessWidget {
  const CalibrationSpine({
    super.key,
    required this.cents,
    required this.noteLabel,
    required this.stringNumber,
    required this.measuredHz,
    required this.targetHz,
    required this.state,
    required this.status,
  });

  final double? cents;
  final String noteLabel;
  final int stringNumber;
  final double? measuredHz;
  final double targetHz;
  final CalibrationSpineState state;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isLocked = state == CalibrationSpineState.locked;
    final isReference = state == CalibrationSpineState.referenceTone;
    final isCoarse = state == CalibrationSpineState.coarse;
    final foreground = isLocked
        ? context.terminal.lockHold
        : isCoarse
        ? context.terminal.amber
        : context.terminal.text;
    final visibleFrequency = measuredHz == null
        ? '— Hz'
        : '${measuredHz!.toStringAsFixed(2)} Hz';
    final noteDetail = '$noteLabel · $stringNumber번 줄';
    final measuredSemantics = measuredHz == null
        ? '측정 대기'
        : '측정 ${measuredHz!.toStringAsFixed(2)} 헤르츠';
    final semanticsLabel =
        '$stringNumber번 줄 $noteLabel, $measuredSemantics, 목표 ${targetHz.toStringAsFixed(2)} 헤르츠, $status.';

    return Semantics(
      key: const Key('calibration-spine'),
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              visibleFrequency,
              textAlign: TextAlign.center,
              style: context.instrumentType.centsHero.copyWith(
                color: isReference ? context.terminal.information : foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            noteDetail,
            textAlign: TextAlign.center,
            style: context.instrumentType.subhead.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          FrequencyReadout(measuredHz: measuredHz, targetHz: targetHz),
          const SizedBox(height: 14),
          PitchTape(cents: cents, locked: isLocked, status: status),
        ],
      ),
    );
  }
}

/// The production, Hz-first tuner face.  The cent value remains an internal
/// position input for the calibrated rail; it is never rendered or announced.
class SharkTuneTuningCore extends StatelessWidget {
  const SharkTuneTuningCore({
    super.key,
    required this.tuningLabel,
    required this.cents,
    required this.noteLabel,
    required this.stringNumber,
    required this.measuredHz,
    required this.targetHz,
    required this.state,
    required this.status,
    this.showBack = false,
    this.onBack,
    this.onStage,
  });

  final String tuningLabel;
  final double? cents;
  final String noteLabel;
  final int stringNumber;
  final double? measuredHz;
  final double targetHz;
  final CalibrationSpineState state;
  final String status;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onStage;

  @override
  Widget build(BuildContext context) {
    final locked = state == CalibrationSpineState.locked;
    final referenceTone = state == CalibrationSpineState.referenceTone;
    final foreground = locked
        ? context.terminal.lockHold
        : state == CalibrationSpineState.coarse
        ? context.terminal.amber
        : context.terminal.text;
    final frequency = measuredHz?.toStringAsFixed(2) ?? '— —.— —';
    final measurementDescription = measuredHz == null
        ? '측정 대기'
        : '현재 ${measuredHz!.toStringAsFixed(2)} 헤르츠';
    return Semantics(
      key: const Key('sharktune-tuning-core'),
      label:
          '$stringNumber번 줄 $noteLabel, $measurementDescription, 목표 ${targetHz.toStringAsFixed(2)} 헤르츠. $status',
      excludeSemantics: true,
      child: Column(
        children: [
          _SharkTuneMasthead(
            tuningLabel: tuningLabel,
            showBack: showBack,
            onBack: onBack,
            onStage: onStage,
          ),
          const SizedBox(height: 12),
          PitchTape(cents: cents, locked: locked, status: status),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$frequency Hz',
              textAlign: TextAlign.center,
              style: context.instrumentType.centsHero.copyWith(
                color: referenceTone
                    ? context.terminal.information
                    : foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$noteLabel  ·  STRING $stringNumber',
            textAlign: TextAlign.center,
            style: context.instrumentType.subhead.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'TARGET ${targetHz.toStringAsFixed(2)} Hz',
            textAlign: TextAlign.center,
            style: context.instrumentType.status.copyWith(
              color: context.terminal.information,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharkTuneMasthead extends StatelessWidget {
  const _SharkTuneMasthead({
    required this.tuningLabel,
    required this.showBack,
    this.onBack,
    this.onStage,
  });

  final String tuningLabel;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onStage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: showBack
                    ? IconButton(
                        tooltip: '뒤로',
                        onPressed: onBack,
                        icon: const Icon(Icons.chevron_left_rounded),
                      )
                    : null,
              ),
              const Spacer(),
              TextButton(
                key: const Key('open-stage-mode'),
                onPressed: onStage,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'STAGE',
                  style: context.instrumentType.status.copyWith(
                    color: context.terminal.information,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandMark(width: 52, height: 42, color: context.terminal.accent),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'SharkTune',
                  key: const Key('sharktune-wordmark'),
                  style: context.instrumentType.centsHero.copyWith(
                    color: context.terminal.text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'OFFLINE PRECISION GUITAR TUNER',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.instrumentType.status.copyWith(
            color: context.terminal.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          tuningLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.instrumentType.status.copyWith(
            color: context.terminal.muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
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
                      '열기',
                      style: context.instrumentType.status.copyWith(
                        color: context.terminal.accent,
                        fontWeight: FontWeight.w600,
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
        ? '출처 검토 중'
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
    this.compact = false,
    this.onTap,
  });

  final String label;
  final int stringNumber;
  final bool active;
  final bool completed;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2).toDouble();
    final width = compact ? 48.0 : 48 + 12 * (textScale - 1);
    final height = compact ? 52.0 : 52 + 32 * (textScale - 1);
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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

/// A continuous guitar-string selector inspired by a physical bridge rather
/// than a row of unrelated application buttons.
class TuningStringRail extends StatelessWidget {
  const TuningStringRail({
    super.key,
    required this.labels,
    required this.stringNumbers,
    required this.selectedIndex,
    required this.completedStringNumbers,
    required this.onSelect,
  }) : assert(labels.length == stringNumbers.length);

  final List<String> labels;
  final List<int> stringNumbers;
  final int selectedIndex;
  final Set<int> completedStringNumbers;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '튜닝 현 선택 레일',
      child: SizedBox(
        key: const Key('tuning-string-rail'),
        height: 82,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _TuningStringRailPainter(
                  stringCount: labels.length,
                  selectedIndex: selectedIndex,
                  terminal: context.terminal,
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: selectedIndex == index,
                        label:
                            '${stringNumbers[index]}번 줄 ${labels[index]}${completedStringNumbers.contains(stringNumbers[index]) ? ', 완료' : ''}',
                        child: InkWell(
                          key: Key('tuning-string-${stringNumbers[index]}'),
                          onTap: () => onSelect(index),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      labels[index],
                                      style: context.instrumentType.caption
                                          .copyWith(
                                            color: selectedIndex == index
                                                ? context.terminal.accent
                                                : context.terminal.text,
                                            fontFamily: 'IBM Plex Mono',
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '${stringNumbers[index]}th',
                                      style: context.instrumentType.status
                                          .copyWith(
                                            color: selectedIndex == index
                                                ? context.terminal.accent
                                                : context.terminal.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TuningStringRailPainter extends CustomPainter {
  const _TuningStringRailPainter({
    required this.stringCount,
    required this.selectedIndex,
    required this.terminal,
  });

  final int stringCount;
  final int selectedIndex;
  final TerminalTheme terminal;

  @override
  void paint(Canvas canvas, Size size) {
    final boundary = Paint()
      ..color = terminal.line
      ..strokeWidth = 1;
    final post = Paint()
      ..color = terminal.surfaceHighlight
      ..strokeWidth = 2;
    final string = Paint()
      ..color = terminal.textSecondary
      ..strokeWidth = 2;
    final active = Paint()
      ..color = terminal.accent
      ..strokeWidth = 3;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), boundary);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      boundary,
    );
    final cellWidth = size.width / stringCount;
    const stringY = 27.0;
    canvas.drawLine(
      Offset(12, stringY),
      Offset(size.width - 12, stringY),
      string,
    );
    for (var index = 0; index <= stringCount; index++) {
      final x = cellWidth * index;
      canvas.drawLine(Offset(x, 8), Offset(x, 54), post);
    }
    final selectedX = cellWidth * (selectedIndex + .5);
    canvas.drawLine(Offset(selectedX, 10), Offset(selectedX, 48), active);
    canvas.drawCircle(Offset(selectedX, stringY), 5, active);
  }

  @override
  bool shouldRepaint(covariant _TuningStringRailPainter oldDelegate) {
    return oldDelegate.stringCount != stringCount ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.terminal != terminal;
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
      value: cents == null ? '주파수 대기' : '현재 주파수 위치',
      child: RepaintBoundary(
        child: SizedBox(
          height: 94,
          width: double.infinity,
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
    const meterTop = 19.0;
    final meterBottom = size.height - 27;
    final meterCenter = (meterTop + meterBottom) / 2;
    double xForCents(double cents) =>
        horizontalPadding + tapeWidth * (cents.clamp(-50, 50) + 50) / 100;
    final greenZone = Paint()
      ..color = terminal.lockHold.withValues(alpha: locked ? 0.24 : 0.1);
    canvas.drawRect(
      Rect.fromLTRB(xForCents(-5), meterTop, xForCents(5), meterBottom),
      greenZone,
    );
    final minor = Paint()
      ..color = terminal.line
      ..strokeWidth = 1;
    final center = Paint()
      ..color = terminal.accent
      ..strokeWidth = 1;
    for (var index = 0; index <= 20; index++) {
      final x = horizontalPadding + tapeWidth * index / 20;
      final isMajor = index % 5 == 0;
      final height = isMajor ? 30.0 : 14.0;
      canvas.drawLine(
        Offset(x, meterCenter - height / 2),
        Offset(x, meterCenter + height / 2),
        index == 10 ? center : minor,
      );
    }
    _paintLabel(canvas, 'LOW', Offset(horizontalPadding, size.height - 18));
    _paintLabel(
      canvas,
      'TARGET',
      Offset(size.width / 2, size.height - 18),
      alignment: TextAlign.center,
      color: terminal.information,
    );
    _paintLabel(
      canvas,
      'HIGH',
      Offset(size.width - horizontalPadding, size.height - 18),
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
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(x, meterTop + 2),
        Offset(x, meterBottom - 2),
        marker,
      );
      final triangle = Path()
        ..moveTo(x - 7, meterTop - 8)
        ..lineTo(x + 7, meterTop - 8)
        ..lineTo(x, meterTop + 1)
        ..close();
      canvas.drawPath(triangle, marker);
      if (absoluteCents > 50) {
        final pointsRight = measuredCents > 0;
        final chevron = Path();
        if (pointsRight) {
          chevron
            ..moveTo(size.width - 14, meterCenter - 10)
            ..lineTo(size.width - 6, meterCenter)
            ..lineTo(size.width - 14, meterCenter + 10);
        } else {
          chevron
            ..moveTo(14, meterCenter - 10)
            ..lineTo(6, meterCenter)
            ..lineTo(14, meterCenter + 10);
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
    Color? color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: type.status.copyWith(
          color: color ?? terminal.muted,
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
