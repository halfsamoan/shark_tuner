import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../app/instrument_theme.dart';
import '../tuner/live_tuner_engine.dart';
import '../tuner/precision_tuner_screen.dart';
import '../ui/instrument_widgets.dart';

class SongDetailScreen extends StatelessWidget {
  const SongDetailScreen({
    super.key,
    required this.match,
    required this.catalog,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
  });

  final SongTuningMatch match;
  final SongCatalog catalog;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;

  @override
  Widget build(BuildContext context) {
    final song = match.song;
    final tuning = match.tuning;
    final cents = _formatCents(song.centsOffset);
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '곡 상세', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            const InstrumentSectionLabel('곡 찾기  /  선택한 곡'),
            const SizedBox(height: 16),
            Text(song.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.artist,
                    style: const TextStyle(
                      color: InstrumentColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                VerificationBadge(status: song.verificationStatus),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            const InstrumentSectionLabel(
              'Song setup',
              color: InstrumentColors.accent,
            ),
            const SizedBox(height: 10),
            DefinitionRow(label: '튜닝', value: tuning.name),
            DefinitionRow(
              label: '카포',
              value: song.capoFret == 0 ? '없음' : '${song.capoFret} 프렛',
            ),
            DefinitionRow(
              label: '기준 피치',
              value: 'A4 ${tuning.referenceA4Hz.toStringAsFixed(2)} Hz',
            ),
            DefinitionRow(
              label: '녹음 오프셋',
              value: cents,
              valueColor: song.centsOffset == 0
                  ? InstrumentColors.text
                  : InstrumentColors.accent,
            ),
            DefinitionRow(label: '버전', value: '${tuning.id}@${tuning.version}'),
            const SizedBox(height: 22),
            const InstrumentSectionLabel('Open strings  ·  low → high'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final string in tuning.strings) ...[
                    TuningNoteCell(
                      label: string.label,
                      stringNumber: string.stringNumber,
                    ),
                    if (string != tuning.strings.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _VerificationNotice(song: song),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PrecisionTunerScreen(
                      match: match,
                      catalog: catalog,
                      tunerEngineFactory: tunerEngineFactory,
                      includeUnverifiedSongs: includeUnverifiedSongs,
                    ),
                  ),
                );
              },
              child: const Text('이 곡으로 튜닝'),
            ),
            const SizedBox(height: 12),
            Text(
              song.capoFret > 0
                  ? '개방현을 먼저 맞춘 뒤 카포 ${song.capoFret}를 장착합니다.'
                  : '개방현을 기준으로 낮은 현부터 맞춥니다.',
              style: const TextStyle(
                color: InstrumentColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: '곡 설정 준비됨',
        detail: '${tuning.strings.length}현 │ $cents',
      ),
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.song});

  final SongTuningRecord song;

  @override
  Widget build(BuildContext context) {
    final verified = song.verificationStatus == SongVerificationStatus.verified;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: BoxDecoration(
        color: InstrumentColors.panel,
        border: Border(
          left: BorderSide(
            color: verified ? InstrumentColors.accent : InstrumentColors.amber,
            width: 3,
          ),
          top: const BorderSide(color: InstrumentColors.line),
          right: const BorderSide(color: InstrumentColors.line),
          bottom: const BorderSide(color: InstrumentColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verified ? '독립 출처 검증 완료' : '출처 확인 전 후보 데이터',
            style: TextStyle(
              color: verified
                  ? InstrumentColors.accent
                  : InstrumentColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            verified
                ? '${song.sources.length}개 출처를 사람이 확인했습니다.'
                : '독립 출처 2개와 사람 검증 전에는 출시 카탈로그에 포함되지 않습니다.',
            style: const TextStyle(
              color: InstrumentColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCents(double value) {
  if (value == 0) {
    return '0 cents';
  }
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} cents';
}
