import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../metronome/metronome_screen.dart'; // (Claude)
import '../metronome/song_bpm.dart'; // (Claude)
import '../tension/tension_recommendation_screen.dart';
import '../tuner/live_tuner_engine.dart';
import '../tuner/precision_tuner_screen.dart';
import '../tuning_history/tuning_history_store.dart';
import '../ui/instrument_surface.dart';
import '../ui/instrument_widgets.dart';

class SongDetailScreen extends StatelessWidget {
  const SongDetailScreen({
    super.key,
    required this.match,
    required this.catalog,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
    this.recordTuningHistory = recordTuningHistoryEntry,
    this.tuningHistoryNow = DateTime.now,
  });

  final SongTuningMatch match;
  final SongCatalog catalog;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;
  final TuningHistoryRecorder recordTuningHistory;
  final DateTime Function() tuningHistoryNow;

  @override
  Widget build(BuildContext context) {
    final song = match.song;
    final tuning = match.tuning;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '곡 상세', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            InstrumentSectionLabel('곡 튜닝'),
            const SizedBox(height: 16),
            Text(song.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.artist,
                    style: context.instrumentType.body.copyWith(
                      color: context.terminal.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                VerificationBadge(
                  status: song.verificationStatus,
                  showDevelopmentStatus: includeUnverifiedSongs,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(height: 1),
            const SizedBox(height: 20),
            InstrumentSectionLabel('튜닝', color: context.terminal.accent),
            const SizedBox(height: 10),
            DefinitionRow(label: '튜닝', value: tuning.name),
            DefinitionRow(
              label: '카포',
              value: song.capoFret == 0 ? '없음' : '${song.capoFret} 프렛',
            ),
            DefinitionRow(
              label: '기준 피치',
              value: 'A4 ${tuning.referenceA4Hz.toStringAsFixed(2)} Hz',
              valueStyle: context.instrumentType.measurement,
            ),
            const SizedBox(height: 22),
            InstrumentSectionLabel('개방현 · 저음 → 고음'),
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
            const InstrumentSectionLabel('도구'),
            const SizedBox(height: 8),
            InstrumentSurface(
              key: const Key('song-tools-group'),
              level: InstrumentSurfaceLevel.raised,
              borderRadius: const BorderRadius.all(
                Radius.circular(InstrumentMetrics.radius12),
              ),
              child: Column(
                children: [
                  _MetronomeEntry(songId: song.id),
                  _TensionRecommendationEntry(
                    tuning: tuning,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TensionRecommendationScreen(tuning: tuning),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _VerificationNotice(
              song: song,
              showDevelopmentStatus: includeUnverifiedSongs,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StickyTuneBar(
            instruction: song.capoFret > 0
                ? '현을 맞춘 뒤 카포 ${song.capoFret}프렛'
                : '낮은 줄부터 맞춥니다.',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PrecisionTunerScreen(
                    match: match,
                    catalog: catalog,
                    tunerEngineFactory: tunerEngineFactory,
                    includeUnverifiedSongs: includeUnverifiedSongs,
                    recordTuningHistory: recordTuningHistory,
                    tuningHistoryNow: tuningHistoryNow,
                  ),
                ),
              );
            },
          ),
          InstrumentStatusBar(
            state: '곡 설정 준비됨',
            detail:
                '${tuning.strings.length}현 │ A4 ${tuning.referenceA4Hz.toStringAsFixed(0)} Hz',
          ),
        ],
      ),
    );
  }
}

class _MetronomeEntry extends StatelessWidget {
  const _MetronomeEntry({required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: loadSongBpmIndex(),
      builder: (context, snapshot) {
        final bpm = snapshot.data?[songId];
        return InstrumentActionRow(
          rowKey: const Key('song-metronome-cta'),
          label: '메트로놈',
          detail: bpm == null ? '탭으로 속도 설정' : '$bpm BPM',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MetronomeScreen(initialBpm: bpm ?? 120),
            ),
          ),
        );
      },
    );
  }
}

class _TensionRecommendationEntry extends StatelessWidget {
  const _TensionRecommendationEntry({
    required this.tuning,
    required this.onPressed,
  });

  final TuningDefinition tuning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InstrumentActionRow(
      rowKey: const Key('gauge-recommendation-cta'),
      label: '장력 · 게이지',
      detail: '${tuning.name} · 상위 3개 조합',
      onTap: onPressed,
    );
  }
}

class _StickyTuneBar extends StatelessWidget {
  const _StickyTuneBar({required this.instruction, required this.onPressed});

  final String instruction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      decoration: BoxDecoration(
        color: context.terminal.header,
        border: Border(top: BorderSide(color: context.terminal.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('song-tune-cta'),
              onPressed: onPressed,
              child: const Text('이 곡으로 튜닝'),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            instruction,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.instrumentType.status.copyWith(
              color: context.terminal.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({
    required this.song,
    required this.showDevelopmentStatus,
  });

  final SongTuningRecord song;
  final bool showDevelopmentStatus;

  @override
  Widget build(BuildContext context) {
    final verified = song.verificationStatus == SongVerificationStatus.verified;
    return InstrumentSurface(
      level: InstrumentSurfaceLevel.panel,
      borderRadius: const BorderRadius.all(
        Radius.circular(InstrumentMetrics.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verified
                  ? '검증됨 ✓'
                  : showDevelopmentStatus
                  ? '출처 검토 중'
                  : '튜닝 확인 중',
              style: context.instrumentType.caption.copyWith(
                color: verified
                    ? context.terminal.accent
                    : context.terminal.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              verified
                  ? '출처 ${song.sources.length}개 확인'
                  : showDevelopmentStatus
                  ? '출처를 검토 중입니다. 확인되면 곡 정보가 업데이트됩니다.'
                  : '확인이 끝난 곡만 검색 결과에 표시됩니다.',
              style: context.instrumentType.status.copyWith(
                color: context.terminal.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
