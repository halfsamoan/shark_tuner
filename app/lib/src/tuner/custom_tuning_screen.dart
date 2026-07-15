import 'package:flutter/material.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';

class CustomTuningScreen extends StatefulWidget {
  const CustomTuningScreen({super.key});

  @override
  State<CustomTuningScreen> createState() => _CustomTuningScreenState();
}

class _CustomTuningScreenState extends State<CustomTuningScreen> {
  static const _minimumMidi = 28;
  static const _maximumMidi = 76;
  final _midiNotes = <int>[40, 45, 50, 55, 59, 64];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '내 튜닝', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text('내 튜닝 만들기', style: context.instrumentType.title),
            const SizedBox(height: 6),
            Text(
              '낮은 6번 줄부터 각 줄의 목표 음을 반음 단위로 조절하세요.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < _midiNotes.length; index++) ...[
              _CustomStringRow(
                stringNumber: 6 - index,
                noteLabel: _noteLabel(_midiNotes[index]),
                canLower: _midiNotes[index] > _minimumMidi,
                canRaise: _midiNotes[index] < _maximumMidi,
                onLower: () => _changeNote(index, -1),
                onRaise: () => _changeNote(index, 1),
              ),
              if (index != _midiNotes.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            Text(
              '이 설정은 이번 튜닝에만 사용됩니다.',
              style: context.instrumentType.status.copyWith(
                color: context.terminal.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: context.terminal.header,
            border: Border(top: BorderSide(color: context.terminal.line)),
          ),
          child: FilledButton(
            key: const Key('custom-tuning-start'),
            onPressed: _start,
            child: const Text('이 튜닝으로 시작'),
          ),
        ),
      ),
    );
  }

  void _changeNote(int index, int delta) {
    setState(() {
      _midiNotes[index] = (_midiNotes[index] + delta)
          .clamp(_minimumMidi, _maximumMidi)
          .toInt();
    });
  }

  void _start() {
    final strings = <TuningString>[
      for (var index = 0; index < _midiNotes.length; index++)
        TuningString(
          stringNumber: 6 - index,
          midiNote: _midiNotes[index],
          label: _noteLabel(_midiNotes[index]),
        ),
    ];
    Navigator.of(context).pop(
      TuningDefinition(
        id: 'custom-6-${_midiNotes.join('-')}',
        version: 1,
        name: '내 튜닝',
        strings: strings,
      ),
    );
  }
}

class _CustomStringRow extends StatelessWidget {
  const _CustomStringRow({
    required this.stringNumber,
    required this.noteLabel,
    required this.canLower,
    required this.canRaise,
    required this.onLower,
    required this.onRaise,
  });

  final int stringNumber;
  final String noteLabel;
  final bool canLower;
  final bool canRaise;
  final VoidCallback onLower;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.terminal.panel,
        border: Border.all(color: context.terminal.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stringNumber번 줄',
                  style: context.instrumentType.caption.copyWith(
                    color: context.terminal.textSecondary,
                  ),
                ),
                Text(
                  noteLabel,
                  key: Key('custom-note-$stringNumber'),
                  style: context.instrumentType.subhead.copyWith(
                    fontFamily: 'IBM Plex Mono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton.outlined(
            key: Key('custom-string-$stringNumber-down'),
            tooltip: '$stringNumber번 줄 반음 낮추기',
            onPressed: canLower ? onLower : null,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Text(
              '−',
              style: context.instrumentType.subhead.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: Key('custom-string-$stringNumber-up'),
            tooltip: '$stringNumber번 줄 반음 높이기',
            onPressed: canRaise ? onRaise : null,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Text(
              '+',
              style: context.instrumentType.subhead.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _noteLabel(int midiNote) {
  const names = <String>[
    'C',
    'D♭',
    'D',
    'E♭',
    'E',
    'F',
    'G♭',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];
  return '${names[midiNote % 12]}${midiNote ~/ 12 - 1}';
}
