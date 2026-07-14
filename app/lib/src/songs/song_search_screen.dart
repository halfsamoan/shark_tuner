import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../app/toauner_app.dart';
import '../settings/app_information_screen.dart';
import '../tuner/live_tuner_engine.dart';
import '../tuner/precision_tuner_screen.dart';
import '../ui/instrument_widgets.dart';
import 'song_detail_screen.dart';

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({
    super.key,
    required this.catalogLoader,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
  });

  final SongCatalogLoader catalogLoader;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;

  @override
  State<SongSearchScreen> createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  SongCatalog? _catalog;
  List<SongTuningMatch> _results = const [];
  List<SongTuningMatch> _popularResults = const [];
  bool _loading = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final catalog = await widget.catalogLoader();
      if (!mounted) {
        await catalog.close();
        return;
      }
      _catalog = catalog;
      await _search('');
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _search(String query) async {
    final catalog = _catalog;
    if (catalog == null) {
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await catalog.search(
        query,
        includeUnverified: widget.includeUnverifiedSongs,
      );
      if (mounted && requestId == _requestId) {
        setState(() {
          _results = results;
          if (query.trim().isEmpty) {
            _popularResults = results.take(3).toList(growable: false);
          }
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    final catalog = _catalog;
    if (catalog != null) {
      unawaited(catalog.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InstrumentHeaderBar(
        section: '곡 찾기',
        actions: [
          Semantics(
            label: '개인정보 및 앱 정보',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              key: const Key('app-information'),
              tooltip: '개인정보 및 앱 정보',
              onPressed: _openAppInformation,
              icon: const Text(
                'ⓘ',
                style: TextStyle(
                  color: InstrumentColors.information,
                  fontFamily: 'D2Coding',
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
          children: [
            Text(
              '어떤 곡을 연주하나요?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              '오프라인 카탈로그에서 튜닝을 찾습니다.',
              style: TextStyle(color: InstrumentColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _QuickTunePanel(
              enabled: _catalog != null,
              onSelected: _openDirectTuner,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              autofocus: false,
              style: const TextStyle(
                color: InstrumentColors.text,
                fontSize: 16,
              ),
              cursorColor: InstrumentColors.accent,
              textInputAction: TextInputAction.search,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: '곡명 또는 아티스트 검색',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 20),
            InstrumentSectionLabel('검색 결과  ${_results.length}곡'),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) _CatalogError(onRetry: () => _load()),
            if (!_loading && _error == null && _results.isEmpty)
              _EmptyResults(
                popularResults: _popularResults,
                onShowAll: _showAllSongs,
                onSongSelected: _openSong,
              ),
            if (_error == null)
              for (final match in _results)
                _SongResultRow(match: match, onTap: () => _openSong(match)),
            if (widget.includeUnverifiedSongs) ...[
              const SizedBox(height: 16),
              const Text(
                'DEV·검토 전 후보까지 표시',
                style: TextStyle(
                  color: InstrumentColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _loading
            ? '곡 준비 중'
            : widget.includeUnverifiedSongs
            ? 'DEV·곡 찾기 준비됨'
            : '곡 찾기 준비됨',
        detail: '${_results.length}곡 │ 오프라인',
        active: !_loading && _error == null,
      ),
    );
  }

  void _openDirectTuner(TuningDefinition tuning) {
    final catalog = _catalog;
    if (catalog == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrecisionTunerScreen(
          directTuning: tuning,
          directLabel: '바로 튜닝',
          catalog: catalog,
          tunerEngineFactory: widget.tunerEngineFactory,
          includeUnverifiedSongs: widget.includeUnverifiedSongs,
        ),
      ),
    );
  }

  void _openAppInformation() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AppInformationScreen()),
    );
  }

  void _showAllSongs() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    unawaited(_search(''));
  }

  void _openSong(SongTuningMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongDetailScreen(
          match: match,
          catalog: _catalog!,
          tunerEngineFactory: widget.tunerEngineFactory,
          includeUnverifiedSongs: widget.includeUnverifiedSongs,
        ),
      ),
    );
  }
}

class _QuickTunePanel extends StatelessWidget {
  const _QuickTunePanel({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<TuningDefinition> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InstrumentColors.panel,
        border: Border.all(color: InstrumentColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InstrumentSectionLabel('바로 튜닝', color: InstrumentColors.accent),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('quick-tune-standard'),
              onPressed: enabled
                  ? () => onSelected(BuiltInTunings.standardGuitar)
                  : null,
              icon: const Text(
                '●',
                style: TextStyle(fontFamily: 'D2Coding', fontSize: 11),
              ),
              label: const Text('바로 튜닝하기 · E Standard'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                key: const Key('quick-tune-eb'),
                onPressed: enabled
                    ? () => onSelected(BuiltInTunings.eFlatStandard)
                    : null,
                label: const Text('E♭ Standard'),
              ),
              ActionChip(
                key: const Key('quick-tune-drop-d'),
                onPressed: enabled
                    ? () => onSelected(BuiltInTunings.dropD)
                    : null,
                label: const Text('Drop D'),
              ),
              ActionChip(
                key: const Key('quick-tune-more'),
                onPressed: enabled ? () => _showPresetPicker(context) : null,
                label: const Text('다른 튜닝'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPresetPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: InstrumentColors.raised,
      isScrollControlled: true,
      builder: (sheetContext) => _DirectTuningSheet(
        tunings: BuiltInTunings.sixStringPresets,
        onSelected: (tuning) {
          Navigator.of(sheetContext).pop();
          onSelected(tuning);
        },
      ),
    );
  }
}

class _DirectTuningSheet extends StatelessWidget {
  const _DirectTuningSheet({required this.tunings, required this.onSelected});

  final List<TuningDefinition> tunings;
  final ValueChanged<TuningDefinition> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstrumentSectionLabel(
                    '튜닝 선택',
                    color: InstrumentColors.accent,
                  ),
                  SizedBox(height: 6),
                  Text(
                    '원하는 튜닝을 고르면 각 줄을 목표 음까지 차례로 안내합니다.',
                    style: TextStyle(
                      color: InstrumentColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: tunings.length,
                itemBuilder: (context, index) {
                  final tuning = tunings[index];
                  return InkWell(
                    key: Key('direct-tuning-${tuning.id}'),
                    onTap: () => onSelected(tuning),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 62),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 11,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: InstrumentColors.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: const TextStyle(
                              color: InstrumentColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tuning.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tuning.strings
                                      .map((string) => string.label)
                                      .join('  '),
                                  style: const TextStyle(
                                    color: InstrumentColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongResultRow extends StatelessWidget {
  const _SongResultRow({required this.match, required this.onTap});

  final SongTuningMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = match.song;
    final secondary = switch ((song.capoFret, song.centsOffset)) {
      (> 0, _) => 'CAPO ${song.capoFret}',
      (_, != 0) => _formatCents(song.centsOffset),
      _ => '${match.tuning.referenceA4Hz.toStringAsFixed(0)} Hz',
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: const BoxDecoration(
          color: InstrumentColors.panel,
          border: Border(bottom: BorderSide(color: InstrumentColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: InstrumentColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  match.tuning.name.toUpperCase(),
                  style: const TextStyle(
                    color: InstrumentColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  secondary,
                  style: const TextStyle(
                    color: InstrumentColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.popularResults,
    required this.onShowAll,
    required this.onSongSelected,
  });

  final List<SongTuningMatch> popularResults;
  final VoidCallback onShowAll;
  final ValueChanged<SongTuningMatch> onSongSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: InstrumentColors.text),
          ),
          const SizedBox(height: 5),
          const Text(
            '곡명 철자를 확인하거나 아티스트 이름으로 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: InstrumentColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton(
              key: const Key('show-all-songs'),
              onPressed: onShowAll,
              child: const Text('전체 곡 다시 보기'),
            ),
          ),
          if (popularResults.isNotEmpty) ...[
            const SizedBox(height: 28),
            const InstrumentSectionLabel('추천 곡'),
            const SizedBox(height: 8),
            for (final match in popularResults)
              _SongResultRow(match: match, onTap: () => onSongSelected(match)),
          ],
        ],
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text(
            '곡 카탈로그를 열지 못했습니다.',
            style: TextStyle(color: InstrumentColors.danger),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

String _formatCents(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} cents';
}
