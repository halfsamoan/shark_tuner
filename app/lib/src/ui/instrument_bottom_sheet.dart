import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';

/// Shared mobile sheet behavior, rendered with the active toauner surface.
Future<T?> showInstrumentBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: true,
    showDragHandle: showDragHandle && enableDrag,
    backgroundColor: context.terminal.raised,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(InstrumentMetrics.radius16),
      ),
    ),
  );
}
