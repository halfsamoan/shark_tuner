import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/app_preferences.dart';
import '../app/instrument_theme.dart';
import '../app/toauner_app.dart';
import '../metronome/metronome_screen.dart';
import '../settings/app_information_screen.dart';
import '../settings/app_preferences_screen.dart';
import '../string_care/string_care_screen.dart';
import '../string_care/string_care_store.dart';
import '../tuner/live_tuner_engine.dart';
import '../tuner/precision_tuner_screen.dart';
import '../tuning_history/tuning_history_model.dart';
import '../tuning_history/tuning_history_screen.dart';
import '../tuning_history/tuning_history_store.dart';
import '../ui/instrument_widgets.dart';
import '../ui/tool_menu_sheet.dart';
import 'song_detail_screen.dart';

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({
    super.key,
    required this.catalogLoader,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
    required this.stringCareLoader,
    required this.stringCareSaver,
    required this.stringCareNow,
    required this.tuningHistoryLoader,
    required this.tuningHistorySaver,
    required this.tuningHistoryRecorder,
    required this.tuningHistoryNow,
  });

  final SongCatalogLoader catalogLoader;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;
  final StringCareLoader stringCareLoader;
  final StringCareSaver stringCareSaver;
  final DateTime Function() stringCareNow;
  final TuningHistoryLoader tuningHistoryLoader;
  final TuningHistorySaver tuningHistorySaver;
  final TuningHistoryRecorder tuningHistoryRecorder;
  final DateTime Function() tuningHistoryNow;

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
  Timer? _searchDebounce;
  var _tuningHistoryLedger = TuningHistoryLedger.empty();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadTuningHistory());
  }

  Future<void> _loadTuningHistory() async {
    try {
      final ledger = await widget.tuningHistoryLoader();
      if (mounted) {
        setState(() => _tuningHistoryLedger = ledger);
      }
    } on Object {
      // Song search remains usable if local session history is unavailable.
    }
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

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_search(query)),
    );
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    unawaited(_search(''));
    setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
            label: '도구 메뉴',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              key: const Key('tool-menu-entry'),
              onPressed: _openToolMenu,
              child: Text(
                '도구',
                style: context.instrumentType.caption.copyWith(
                  color: context.terminal.accent,
                  fontWeight: FontWeight.w700,
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
            Text(
              '곡을 고르면 맞는 튜닝으로 바로 이어집니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('song-search-field'),
              controller: _searchController,
              autofocus: false,
              style: context.instrumentType.body.copyWith(
                color: context.terminal.text,
              ),
              cursorColor: context.terminal.accent,
              textInputAction: TextInputAction.search,
              onChanged: _scheduleSearch,
              onSubmitted: (query) {
                _searchDebounce?.cancel();
                unawaited(_search(query));
              },
              decoration: InputDecoration(
                hintText: '곡명 또는 아티스트 검색',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('clear-song-search'),
                        tooltip: '검색어 지우기',
                        onPressed: _clearSearch,
                        icon: Text(
                          '×',
                          style: context.instrumentType.subhead.copyWith(
                            color: context.terminal.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
            if (_searchController.text.isEmpty &&
                context.appPreferences.value.recentSearches.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RecentSearches(
                queries: context.appPreferences.value.recentSearches,
                onSelected: _selectRecentSearch,
                onClear: context.appPreferences.clearRecentSearches,
              ),
            ],
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
            const SizedBox(height: 18),
            _QuickTunePanel(
              enabled: _catalog != null,
              onSelected: _openDirectTuner,
            ),
            if (widget.includeUnverifiedSongs) ...[
              const SizedBox(height: 16),
              Text(
                'DEV·검토 전 후보까지 표시',
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.amber,
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

  Future<void> _openDirectTuner(TuningDefinition tuning) async {
    final catalog = _catalog;
    if (catalog == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrecisionTunerScreen(
          directTuning: tuning,
          directLabel: '바로 튜닝',
          catalog: catalog,
          tunerEngineFactory: widget.tunerEngineFactory,
          includeUnverifiedSongs: widget.includeUnverifiedSongs,
          recordTuningHistory: widget.tuningHistoryRecorder,
          tuningHistoryNow: widget.tuningHistoryNow,
        ),
      ),
    );
    if (mounted) {
      await _loadTuningHistory();
    }
  }

  void _openAppInformation() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AppInformationScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AppPreferencesScreen()),
    );
  }

  void _openMetronome() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const MetronomeScreen()));
  }

  void _openToolMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.terminal.raised,
      isScrollControlled: true,
      builder: (sheetContext) => ToolMenuSheet(
        historyCount: _tuningHistoryLedger.entries.length,
        onMetronome: () {
          Navigator.of(sheetContext).pop();
          _openMetronome();
        },
        onHistory: () {
          Navigator.of(sheetContext).pop();
          unawaited(_openTuningHistory());
        },
        onStringCare: () {
          Navigator.of(sheetContext).pop();
          unawaited(_openStringCare());
        },
        onSettings: () {
          Navigator.of(sheetContext).pop();
          _openSettings();
        },
        onInformation: () {
          Navigator.of(sheetContext).pop();
          _openAppInformation();
        },
      ),
    );
  }

  Future<void> _openStringCare() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StringCareScreen(
          loader: widget.stringCareLoader,
          saver: widget.stringCareSaver,
          now: widget.stringCareNow,
        ),
      ),
    );
  }

  Future<void> _openTuningHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TuningHistoryScreen(
          loader: widget.tuningHistoryLoader,
          saver: widget.tuningHistorySaver,
        ),
      ),
    );
    if (mounted) {
      await _loadTuningHistory();
    }
  }

  void _showAllSongs() {
    _clearSearch();
  }

  void _selectRecentSearch(String query) {
    _searchDebounce?.cancel();
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    unawaited(_search(query));
    setState(() {});
  }

  Future<void> _openSong(SongTuningMatch match) async {
    final query = _searchController.text.trim();
    context.appPreferences.recordRecentSearch(
      query.isEmpty ? match.song.title : query,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongDetailScreen(
          match: match,
          catalog: _catalog!,
          tunerEngineFactory: widget.tunerEngineFactory,
          includeUnverifiedSongs: widget.includeUnverifiedSongs,
          recordTuningHistory: widget.tuningHistoryRecorder,
          tuningHistoryNow: widget.tuningHistoryNow,
        ),
      ),
    );
    if (mounted) {
      await _loadTuningHistory();
    }
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.queries,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> queries;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: InstrumentSectionLabel('최근 검색')),
            TextButton(
              key: const Key('clear-recent-searches'),
              onPressed: onClear,
              child: const Text('전체 지우기'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in queries)
              ActionChip(
                key: Key('recent-search-$query'),
                onPressed: () => onSelected(query),
                label: Text(query),
              ),
          ],
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.terminal.panel,
        border: Border.all(color: context.terminal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: InstrumentSectionLabel('곡 없이 튜닝')),
              OutlinedButton(
                key: const Key('quick-tune-standard'),
                onPressed: enabled
                    ? () => onSelected(BuiltInTunings.standardGuitar)
                    : null,
                child: const Text('E Standard 시작'),
              ),
            ],
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
      backgroundColor: context.terminal.raised,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstrumentSectionLabel(
                    '튜닝 선택',
                    color: context.terminal.accent,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '원하는 튜닝을 고르면 각 줄을 목표 음까지 차례로 안내합니다.',
                    style: context.instrumentType.caption.copyWith(
                      color: context.terminal.muted,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
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
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: context.terminal.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: context.instrumentType.status.copyWith(
                              color: context.terminal.muted,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tuning.name,
                                  style: context.instrumentType.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tuning.strings
                                      .map((string) => string.label)
                                      .join('  '),
                                  style: context.instrumentType.status.copyWith(
                                    color: context.terminal.muted,
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
        decoration: BoxDecoration(
          color: context.terminal.panel,
          border: Border(bottom: BorderSide(color: context.terminal.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: context.instrumentType.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: context.instrumentType.caption.copyWith(
                      color: context.terminal.muted,
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
                  style: context.instrumentType.status.copyWith(
                    color: context.terminal.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  secondary,
                  style: context.instrumentType.status.copyWith(
                    color: context.terminal.muted,
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
          Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: context.instrumentType.body.copyWith(
              color: context.terminal.text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '곡명 철자를 확인하거나 아티스트 이름으로 찾아보세요.',
            textAlign: TextAlign.center,
            style: context.instrumentType.caption.copyWith(
              color: context.terminal.muted,
            ),
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
            InstrumentSectionLabel('추천 곡'),
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
          Text(
            '곡 카탈로그를 열지 못했습니다.',
            style: TextStyle(color: context.terminal.danger),
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
