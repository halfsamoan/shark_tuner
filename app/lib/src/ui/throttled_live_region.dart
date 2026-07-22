import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps visual feedback immediate while limiting screen-reader announcements.
class ThrottledLiveRegion extends StatefulWidget {
  const ThrottledLiveRegion({
    super.key,
    required this.label,
    required this.child,
    this.minimumInterval = const Duration(seconds: 1),
  });

  final String label;
  final Widget child;
  final Duration minimumInterval;

  @override
  State<ThrottledLiveRegion> createState() => _ThrottledLiveRegionState();
}

class _ThrottledLiveRegionState extends State<ThrottledLiveRegion> {
  Timer? _gateTimer;
  late String _announcedLabel;
  String? _pendingLabel;

  @override
  void initState() {
    super.initState();
    _announcedLabel = widget.label;
    _startGate();
  }

  @override
  void didUpdateWidget(covariant ThrottledLiveRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label == _announcedLabel || widget.label == _pendingLabel) {
      return;
    }
    if (_gateTimer == null) {
      _announce(widget.label);
    } else {
      _pendingLabel = widget.label;
    }
  }

  @override
  void dispose() {
    _gateTimer?.cancel();
    super.dispose();
  }

  void _announce(String label) {
    setState(() => _announcedLabel = label);
    _startGate();
  }

  void _startGate() {
    _gateTimer?.cancel();
    _gateTimer = Timer(widget.minimumInterval, () {
      if (!mounted) {
        return;
      }
      final pending = _pendingLabel;
      _pendingLabel = null;
      _gateTimer = null;
      if (pending != null && pending != _announcedLabel) {
        _announce(pending);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: _announcedLabel,
      excludeSemantics: true,
      child: widget.child,
    );
  }
}
