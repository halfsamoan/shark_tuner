import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';

enum InstrumentSurfaceLevel { sunken, panel, raised, header }

class InstrumentSurface extends StatelessWidget {
  const InstrumentSurface({
    super.key,
    required this.child,
    this.level = InstrumentSurfaceLevel.panel,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
  });

  final Widget child;
  final InstrumentSurfaceLevel level;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final terminal = context.terminal;
    final background = switch (level) {
      InstrumentSurfaceLevel.sunken => terminal.sunken,
      InstrumentSurfaceLevel.panel => terminal.panel,
      InstrumentSurfaceLevel.raised => terminal.raised,
      InstrumentSurfaceLevel.header => terminal.header,
    };
    final paperShadow =
        terminal.brightness == Brightness.light &&
        level != InstrumentSurfaceLevel.sunken;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: terminal.line),
        boxShadow: paperShadow
            ? [
                BoxShadow(
                  color: terminal.surfaceGroundLine,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: ColoredBox(
                  color: terminal.surfaceHighlight,
                  child: const SizedBox(height: 1),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: ColoredBox(
                  color: terminal.surfaceGroundLine,
                  child: const SizedBox(height: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
