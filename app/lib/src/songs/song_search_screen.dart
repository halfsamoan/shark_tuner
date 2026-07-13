import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner_data/tuner_data.dart';

import '../app/instrument_theme.dart';
import '../app/toauner_app.dart';
import '../ui/instrument_widgets.dart';
import 'song_detail_screen.dart';

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({
    super.key,
    required this.catalogLoader,
    required this.includeUnverifiedSongs,
  });

  final SongCatalogLoader catalogLoader;
  final bool includeUnverifiedSongs;

  @override
  State<SongSearchScreen> createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  SongCatalog? _catalog;
  List<SongTuningMatch> _results = const [];
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
    final catalog = _catalog;
    if (catalog != null) {
      unawaited(catalog.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '곡 찾기'),
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
            const SizedBox(height: 20),
            TextField(
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
                suffixIcon: _ShortcutHint(),
                suffixIconConstraints: BoxConstraints.tightFor(
                  width: 64,
                  height: 48,
                ),
              ),
            ),
            const SizedBox(height: 20),
            InstrumentSectionLabel(
              'Results  ${_results.length}  /  ${widget.includeUnverifiedSongs ? 'development' : 'verified'} catalog',
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) _CatalogError(onRetry: () => _load()),
            if (!_loading && _error == null && _results.isEmpty)
              const _EmptyResults(),
            if (_error == null)
              for (final match in _results)
                _SongResultRow(
                  match: match,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongDetailScreen(
                          match: match,
                          catalog: _catalog!,
                          includeUnverifiedSongs: widget.includeUnverifiedSongs,
                        ),
                      ),
                    );
                  },
                ),
            if (widget.includeUnverifiedSongs) ...[
              const SizedBox(height: 16),
              const Text(
                '●  미검증 곡은 개발 빌드에서만 표시',
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
        state: _loading ? 'catalog loading' : 'catalog ready',
        detail: 'FTS5 · local',
        active: !_loading && _error == null,
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: InstrumentColors.chrome,
          border: Border.all(color: InstrumentColors.line),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          'Ctrl K',
          style: TextStyle(color: InstrumentColors.muted, fontSize: 9),
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
          color: InstrumentColors.chrome,
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
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: InstrumentColors.muted),
          SizedBox(height: 10),
          Text('검색 결과가 없습니다.', style: TextStyle(color: InstrumentColors.muted)),
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
