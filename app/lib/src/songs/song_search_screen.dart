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
import '../tuner/custom_tuning_screen.dart';
import '../tuner/precision_tuner_screen.dart';
import '../tuning_history/tuning_history_model.dart';
import '../tuning_history/tuning_history_screen.dart';
import '../tuning_history/tuning_history_store.dart';
import '../ui/instrument_bottom_sheet.dart';
import '../ui/instrument_surface.dart';
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
    this.startWithStandardTuning = false,
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
  final bool startWithStandardTuning;

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
  var _showSongSearch = false;
  var _openedLaunchTuner = false;

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
      if (widget.startWithStandardTuning && mounted && !_openedLaunchTuner) {
        _openedLaunchTuner = true;
        await _openDirectTuner(BuiltInTunings.standardGuitar);
      }
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
        section: _showSongSearch ? '곡 찾기' : '튜닝',
        actions: [
          if (_showSongSearch)
            TextButton(
              key: const Key('tuning-home-entry'),
              onPressed: () => setState(() => _showSongSearch = false),
              child: Text(
                '튜닝',
                style: context.instrumentType.caption.copyWith(
                  color: context.terminal.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
        child: _showSongSearch
            ? _buildSongSearchBody(context)
            : _buildTuningHome(context),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _loading
            ? '튜너 준비 중'
            : _showSongSearch
            ? '곡 찾기 준비됨'
            : '튜너 준비됨',
        detail: _showSongSearch ? '${_results.length}곡 │ 오프라인' : 'MIC │ 로컬 처리',
        active: !_loading && _error == null,
      ),
    );
  }

  Widget _buildTuningHome(BuildContext context) {
    return ListView(
      key: const Key('free-tuning-home'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      children: [
        Text('바로 튜닝', style: context.instrumentType.title),
        const SizedBox(height: 8),
        Text(
          '기본 설정에서 시작하거나 프리셋을 고르세요.',
          style: context.instrumentType.caption.copyWith(
            color: context.terminal.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _QuickTunePanel(
          enabled: _catalog != null,
          onSelected: _openDirectTuner,
          onCustom: _openCustomTuning,
        ),
        const SizedBox(height: 28),
        const InstrumentSectionLabel('곡으로 찾기'),
        const SizedBox(height: 10),
        InstrumentActionRow(
          rowKey: const Key('song-search-entry'),
          label: '곡 튜닝 찾기',
          detail: '곡명 · 아티스트',
          onTap: () => setState(() => _showSongSearch = true),
        ),
      ],
    );
  }

  Widget _buildSongSearchBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      children: [
        Text('어떤 곡을 연주하나요?', style: context.instrumentType.title),
        const SizedBox(height: 6),
        Text(
          '곡을 고르면 맞는 튜닝으로 바로 이어집니다.',
          style: context.instrumentType.caption.copyWith(
            color: context.terminal.textSecondary,
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
        if (_error != null) _CatalogError(onRetry: _load),
        if (!_loading && _error == null && _results.isEmpty)
          _EmptyResults(
            popularResults: _popularResults,
            onShowAll: _showAllSongs,
            onSongSelected: _openSong,
          ),
        if (_error == null && _results.isNotEmpty)
          InstrumentSurface(
            key: const Key('song-result-group'),
            level: InstrumentSurfaceLevel.raised,
            borderRadius: const BorderRadius.all(
              Radius.circular(InstrumentMetrics.radius12),
            ),
            child: Column(
              children: [
                for (final match in _results)
                  _SongResultRow(match: match, onTap: () => _openSong(match)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openCustomTuning() async {
    final tuning = await Navigator.of(context).push<TuningDefinition>(
      MaterialPageRoute(builder: (_) => const CustomTuningScreen()),
    );
    if (tuning != null && mounted) {
      await _openDirectTuner(tuning);
    }
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
    showInstrumentBottomSheet<void>(
      context: context,
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
  const _QuickTunePanel({
    required this.enabled,
    required this.onSelected,
    required this.onCustom,
  });

  final bool enabled;
  final ValueChanged<TuningDefinition> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return InstrumentSurface(
      level: InstrumentSurfaceLevel.raised,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      borderRadius: const BorderRadius.all(
        Radius.circular(InstrumentMetrics.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InstrumentSectionLabel('6현 기타 · 기본'),
          const SizedBox(height: 8),
          Text('E Standard', style: context.instrumentType.subhead),
          const SizedBox(height: 4),
          Text(
            'E2   A2   D3   G3   B3   E4',
            style: context.instrumentType.measurement.copyWith(
              color: context.terminal.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('quick-tune-standard'),
              onPressed: enabled
                  ? () => onSelected(BuiltInTunings.standardGuitar)
                  : null,
              child: const Text('E Standard로 튜닝'),
            ),
          ),
          const SizedBox(height: 12),
          InstrumentSurface(
            level: InstrumentSurfaceLevel.sunken,
            borderRadius: const BorderRadius.all(
              Radius.circular(InstrumentMetrics.radius8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuickTunePresetButton(
                    key: const Key('quick-tune-eb'),
                    onPressed: enabled
                        ? () => onSelected(BuiltInTunings.eFlatStandard)
                        : null,
                    label: 'E♭',
                  ),
                ),
                Expanded(
                  child: _QuickTunePresetButton(
                    key: const Key('quick-tune-drop-d'),
                    onPressed: enabled
                        ? () => onSelected(BuiltInTunings.dropD)
                        : null,
                    label: 'Drop D',
                    showLeadingDivider: true,
                  ),
                ),
                Expanded(
                  child: _QuickTunePresetButton(
                    key: const Key('quick-tune-more'),
                    onPressed: enabled
                        ? () => _showPresetPicker(context)
                        : null,
                    label: '더보기',
                    showLeadingDivider: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _QuickTuneCustomEntry(enabled: enabled, onTap: onCustom),
        ],
      ),
    );
  }

  void _showPresetPicker(BuildContext context) {
    showInstrumentBottomSheet<void>(
      context: context,
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

class _QuickTunePresetButton extends StatelessWidget {
  const _QuickTunePresetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showLeadingDivider = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showLeadingDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showLeadingDivider
            ? Border(left: BorderSide(color: context.terminal.line))
            : null,
      ),
      child: SizedBox(
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 48),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _QuickTuneCustomEntry extends StatelessWidget {
  const _QuickTuneCustomEntry({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('custom-tuning-entry'),
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(
          Radius.circular(InstrumentMetrics.radius8),
        ),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 튜닝',
                        style: context.instrumentType.body.copyWith(
                          color: enabled
                              ? context.terminal.text
                              : context.terminal.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '현과 음을 직접 설정',
                        style: context.instrumentType.status.copyWith(
                          color: context.terminal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '설정',
                  style: context.instrumentType.status.copyWith(
                    color: enabled
                        ? context.terminal.accent
                        : context.terminal.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final secondary = song.capoFret > 0
        ? 'CAPO ${song.capoFret}'
        : '${match.tuning.referenceA4Hz.toStringAsFixed(0)} Hz';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
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
              const SizedBox(width: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        InstrumentStatePanel(
          tone: InstrumentStateTone.neutral,
          title: '검색 결과 없음',
          detail: '곡명 또는 아티스트를 확인해 보세요',
          actionKey: const Key('show-all-songs'),
          actionLabel: '전체 곡 보기',
          onAction: onShowAll,
        ),
        if (popularResults.isNotEmpty) ...[
          const SizedBox(height: 28),
          InstrumentSectionLabel('추천 곡'),
          const SizedBox(height: 8),
          for (final match in popularResults)
            _SongResultRow(match: match, onTap: () => onSongSelected(match)),
        ],
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: InstrumentStatePanel(
        tone: InstrumentStateTone.danger,
        title: '곡을 불러올 수 없음',
        detail: '연결을 확인하고 다시 시도해 보세요',
        actionLabel: '다시 시도',
        onAction: onRetry,
      ),
    );
  }
}
