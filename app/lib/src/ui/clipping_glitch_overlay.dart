import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';

class ClippingGlitchOverlay extends StatelessWidget {
  const ClippingGlitchOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final terminal = context.terminal;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            key: const Key('clipping-global-glitch'),
            painter: _ClippingGlitchPainter(
              magenta: terminal.accent,
              cyan: terminal.phosphorEdge,
              ink: terminal.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClippingGlitchPainter extends CustomPainter {
  const _ClippingGlitchPainter({
    required this.magenta,
    required this.cyan,
    required this.ink,
  });

  final Color magenta;
  final Color cyan;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final magentaPaint = Paint()..color = magenta.withValues(alpha: .92);
    final cyanPaint = Paint()..color = cyan.withValues(alpha: .86);
    final inkPaint = Paint()..color = ink.withValues(alpha: .78);
    final scanPaint = Paint()
      ..color = ink.withValues(alpha: .13)
      ..strokeWidth = 1;

    for (var y = 19.0; y < size.height; y += 31) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    canvas.drawRect(Rect.fromLTWH(0, size.height * .116, 7, 83), magentaPaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 5, size.height * .284, 5, 126),
      cyanPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .492, size.width * .18, 3),
      inkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .14,
        size.height * .492 + 4,
        size.width * .34,
        2,
      ),
      magentaPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .67, size.height * .728, size.width * .33, 4),
      cyanPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .76,
        size.height * .728 - 3,
        size.width * .18,
        2,
      ),
      magentaPaint,
    );

    _drawRegistrationCross(
      canvas,
      const Offset(14, 88),
      cyanPaint,
      magentaPaint,
    );
    _drawRegistrationCross(
      canvas,
      Offset(size.width - 22, size.height - 74),
      magentaPaint,
      cyanPaint,
    );
  }

  void _drawRegistrationCross(
    Canvas canvas,
    Offset origin,
    Paint first,
    Paint second,
  ) {
    canvas.drawRect(Rect.fromLTWH(origin.dx - 7, origin.dy, 20, 2), first);
    canvas.drawRect(Rect.fromLTWH(origin.dx + 2, origin.dy - 8, 2, 20), first);
    canvas.drawRect(Rect.fromLTWH(origin.dx - 9, origin.dy + 3, 20, 2), second);
    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy - 5, 2, 20), second);
  }

  @override
  bool shouldRepaint(_ClippingGlitchPainter oldDelegate) =>
      oldDelegate.magenta != magenta ||
      oldDelegate.cyan != cyan ||
      oldDelegate.ink != ink;
}
