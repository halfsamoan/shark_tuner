// (Claude) Standalone metronome. Terminal-authentic layout: no floating cards —
// left-anchored rows, hairline dividers, monospace numerals, block-glyph beats.
// Uses named type roles (no literal font sizes) per the design playbook.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_preferences.dart';
import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';
import 'metronome_player.dart';

const _timeSignatures = <(int, String)>[
  (2, '2/4'),
  (3, '3/4'),
  (4, '4/4'),
  (6, '6/8'),
];

TextStyle _mono(BuildContext context) =>
    context.instrumentType.subhead.copyWith(fontFamily: 'IBM Plex Mono');

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({
    super.key,
    this.initialBpm = 120,
    this.playerFactory = createMetronomePlayer,
  });

  final int initialBpm;
  final MetronomePlayerFactory playerFactory;

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  late final MetronomePlayer _player = widget.playerFactory();
  late int _bpm = widget.initialBpm.clamp(40, 240);
  int _beatsPerBar = 4;
  bool _running = false;
  int _beat = 0;
  Timer? _visualTimer;
  final _taps = <DateTime>[];

  @override
  void dispose() {
    _visualTimer?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() => _running ? _stop() : _start();

  Future<void> _start() async {
    // (Claude) Toggle the UI immediately so the control always responds, then
    // start audio; surface a failure instead of failing silently.
    setState(() {
      _running = true;
      _beat = 0;
    });
    try {
      await _player.play(bpm: _bpm, beatsPerBar: _beatsPerBar);
      _startVisualSync();
    } on Object {
      _visualTimer?.cancel();
      if (mounted) {
        setState(() => _running = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소리를 재생할 수 없습니다. 미디어 볼륨을 확인해 주세요.')),
        );
      }
    }
  }

  Future<void> _stop() async {
    _visualTimer?.cancel();
    await _player.stop();
    if (mounted) {
      setState(() => _running = false);
    }
  }

  // (Claude) Drive the beat indicator from the audio's playback position so it
  // stays locked to what is actually sounding, not a drifting local timer.
  void _startVisualSync() {
    _visualTimer?.cancel();
    var polling = false;
    _visualTimer = Timer.periodic(const Duration(milliseconds: 25), (_) async {
      if (!mounted || !_running || polling) return;
      polling = true;
      try {
        final position = await _player.position();
        final beatMs = 60000 / _bpm;
        final beat = (position.inMilliseconds / beatMs).floor() % _beatsPerBar;
        if (mounted && beat != _beat) {
          setState(() => _beat = beat);
        }
      } on Object {
        // Ignore a dropped position sample; the next tick recovers.
      } finally {
        polling = false;
      }
    });
  }

  Future<void> _setBpm(int value) async {
    final next = value.clamp(40, 240);
    if (next == _bpm) return;
    setState(() => _bpm = next);
    if (_running) {
      await _player.play(bpm: _bpm, beatsPerBar: _beatsPerBar);
      _startVisualSync();
    }
  }

  Future<void> _setBeats(int beats) async {
    setState(() => _beatsPerBar = beats);
    if (_running) {
      await _player.play(bpm: _bpm, beatsPerBar: _beatsPerBar);
      _startVisualSync();
    }
  }

  void _tap() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    _taps.add(now);
    _taps.removeWhere((t) => now.difference(t).inMilliseconds > 3000);
    if (_taps.length >= 2) {
      final intervals = <int>[
        for (var i = 1; i < _taps.length; i++)
          _taps[i].difference(_taps[i - 1]).inMilliseconds,
      ]..sort();
      final median = intervals[intervals.length ~/ 2];
      if (median > 0) {
        _setBpm((60000 / median).round());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.terminal.canvas,
      appBar: const InstrumentHeaderBar(section: '메트로놈', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InstrumentSectionLabel('TEMPO'),
              const SizedBox(height: 4),
              _BpmRow(
                bpm: _bpm,
                onMinus: () => _setBpm(_bpm - 1),
                onPlus: () => _setBpm(_bpm + 1),
                onMinus5: () => _setBpm(_bpm - 5),
                onPlus5: () => _setBpm(_bpm + 5),
              ),
              const SizedBox(height: 20),
              _BeatBar(beats: _beatsPerBar, current: _running ? _beat : -1),
              const SizedBox(height: 24),
              const _Hairline(),
              _TimeSignatureRow(beats: _beatsPerBar, onChanged: _setBeats),
              const _Hairline(),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _GhostButton(label: '탭 템포', onPressed: _tap),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _PrimaryButton(
                      label: _running ? '정지' : '시작',
                      active: _running,
                      onPressed: _toggle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BpmRow extends StatelessWidget {
  const _BpmRow({
    required this.bpm,
    required this.onMinus,
    required this.onPlus,
    required this.onMinus5,
    required this.onPlus5,
  });

  final int bpm;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onMinus5;
  final VoidCallback onPlus5;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stepper(glyph: '−−', onPressed: onMinus5),
        _Stepper(glyph: '−', onPressed: onMinus),
        Expanded(
          child: Column(
            children: [
              Text(
                '$bpm',
                textAlign: TextAlign.center,
                style: context.instrumentType.centsHero.copyWith(
                  color: context.terminal.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'BPM',
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.textSecondary,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        _Stepper(glyph: '+', onPressed: onPlus),
        _Stepper(glyph: '++', onPressed: onPlus5),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.glyph, required this.onPressed});

  final String glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 32,
      child: SizedBox(
        width: 48,
        height: 56,
        child: Center(
          child: Text(
            glyph,
            style: _mono(context).copyWith(color: context.terminal.ink),
          ),
        ),
      ),
    );
  }
}

class _BeatBar extends StatelessWidget {
  const _BeatBar({required this.beats, required this.current});

  final int beats;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < beats; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _BeatBlock(active: i == current, accent: i == 0),
          ),
      ],
    );
  }
}

class _BeatBlock extends StatelessWidget {
  const _BeatBlock({required this.active, required this.accent});

  final bool active;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final onColor = accent
        ? context.terminal.lockFlood
        : context.terminal.accent;
    return AnimatedContainer(
      duration: shouldReduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 70),
      width: accent ? 30 : 24,
      height: 44,
      decoration: BoxDecoration(
        color: active ? onColor : context.terminal.gridTick,
        border: Border.all(
          color: active ? onColor : context.terminal.line,
          width: 1,
        ),
      ),
    );
  }
}

class _TimeSignatureRow extends StatelessWidget {
  const _TimeSignatureRow({required this.beats, required this.onChanged});

  final int beats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            '박자',
            style: context.instrumentType.body.copyWith(
              color: context.terminal.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (value, label) in _timeSignatures)
                  InkWell(
                    onTap: () => onChanged(value),
                    child: Text(
                      beats == value ? '[$label]' : label,
                      style: _mono(context).copyWith(
                        color: beats == value
                            ? context.terminal.accent
                            : context.terminal.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.terminal.line);
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.terminal.panel : context.terminal.accent,
          border: Border.all(color: context.terminal.accent, width: 1.5),
        ),
        child: Text(
          active ? '■ $label' : '▶ $label',
          style: context.instrumentType.subhead.copyWith(
            fontWeight: FontWeight.w700,
            color: active
                ? context.terminal.accent
                : context.terminal.accentInk,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: context.terminal.line, width: 1),
        ),
        child: Text(
          label,
          style: context.instrumentType.body.copyWith(
            color: context.terminal.ink,
          ),
        ),
      ),
    );
  }
}
