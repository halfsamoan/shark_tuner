import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';

class PrecisionTunerScreen extends StatefulWidget {
  const PrecisionTunerScreen({
    super.key,
    required this.match,
    required this.catalog,
    required this.includeUnverifiedSongs,
  });

  final SongTuningMatch match;
  final SongCatalog catalog;
  final bool includeUnverifiedSongs;

  @override
  State<PrecisionTunerScreen> createState() => _PrecisionTunerScreenState();
}

class _PrecisionTunerScreenState extends State<PrecisionTunerScreen> {
  var _selectedIndex = 0;

  TuningString get _selected => widget.match.tuning.strings[_selectedIndex];

  double get _targetHz => _selected.targetFrequencyHz(
    referenceA4Hz: widget.match.tuning.referenceA4Hz,
    centsOffset: widget.match.tuning.centsOffset,
  );

  @override
  Widget build(BuildContext context) {
    final song = widget.match.song;
    final tuning = widget.match.tuning;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '정밀 튜너', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Container(
              height: 34,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: InstrumentColors.chrome,
                border: Border.all(color: InstrumentColors.line),
              ),
              child: Text(
                '${song.title.toUpperCase()}  /  ${tuning.name.toUpperCase()}  /  ${_offsetLabel(tuning.centsOffset)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InstrumentColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < tuning.strings.length;
                    index++
                  ) ...[
                    TuningNoteCell(
                      label: tuning.strings[index].label,
                      stringNumber: tuning.strings[index].stringNumber,
                      active: _selectedIndex == index,
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                    if (index != tuning.strings.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 34),
            Text(
              'STRING ${_selected.stringNumber}  ·  TARGET',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _selected.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: InstrumentColors.text,
                fontSize: 62,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InstrumentColors.muted,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'cents · 마이크 신호 대기',
              textAlign: TextAlign.center,
              style: TextStyle(color: InstrumentColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 22),
            const IdlePitchTape(),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '${_targetHz.toStringAsFixed(2)} Hz',
                  style: const TextStyle(
                    color: InstrumentColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'TARGET ${_targetHz.toStringAsFixed(2)} Hz',
                  style: const TextStyle(
                    color: InstrumentColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const DefinitionRow(label: '입력', value: '마이크 연결 준비'),
            DefinitionRow(
              label: '분석',
              value: _selected.midiNote < 40
                  ? '48 kHz · 8192 samples'
                  : '48 kHz · 4096 samples',
            ),
            DefinitionRow(
              label: '곡 오프셋',
              value: _offsetLabel(tuning.centsOffset),
              valueColor: tuning.centsOffset == 0
                  ? InstrumentColors.text
                  : InstrumentColors.accent,
            ),
            DefinitionRow(
              label: '카포',
              value: song.capoFret == 0
                  ? '튜닝 후 장착 없음'
                  : '튜닝 후 ${song.capoFret} 프렛에 장착',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: InstrumentColors.panel,
                border: Border.all(color: InstrumentColors.line),
              ),
              child: Text(
                tuning.centsOffset == 0
                    ? '현을 한 번 튕기면 측정을 시작합니다.'
                    : '곡 기준 ${_offsetLabel(tuning.centsOffset)} 적용',
                style: TextStyle(
                  color: tuning.centsOffset == 0
                      ? InstrumentColors.muted
                      : InstrumentColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<SongTuningMatch>>(
              future: widget.catalog.findPlayableWith(
                tuning,
                includeUnverified: widget.includeUnverifiedSongs,
              ),
              builder: (context, snapshot) {
                final count = snapshot.data?.length;
                if (count == null) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '이 설정으로 바로 연주 가능한 곡 $count개',
                  style: const TextStyle(
                    color: InstrumentColors.muted,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const InstrumentStatusBar(
        state: 'DSP baseline',
        detail: 'mic idle · MPM',
        active: false,
      ),
    );
  }
}

String _offsetLabel(double cents) {
  if (cents == 0) {
    return '0 cents';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(cents == cents.roundToDouble() ? 0 : 1)} cents';
}
