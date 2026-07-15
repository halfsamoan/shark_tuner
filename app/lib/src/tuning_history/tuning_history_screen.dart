import 'dart:async';

import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';
import 'tuning_history_model.dart';
import 'tuning_history_store.dart';

class TuningHistoryScreen extends StatefulWidget {
  const TuningHistoryScreen({
    super.key,
    this.loader = loadTuningHistoryLedger,
    this.saver = saveTuningHistoryLedger,
  });

  final TuningHistoryLoader loader;
  final TuningHistorySaver saver;

  @override
  State<TuningHistoryScreen> createState() => _TuningHistoryScreenState();
}

class _TuningHistoryScreenState extends State<TuningHistoryScreen> {
  TuningHistoryLedger? _ledger;
  Object? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final ledger = await widget.loader();
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기록을 모두 지울까요?'),
        content: const Text('이 기기에 저장된 튜닝 완료 기록만 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-clear-tuning-history'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true || _saving) {
      return;
    }
    setState(() => _saving = true);
    final cleared = TuningHistoryLedger.empty();
    try {
      await widget.saver(cleared);
      if (mounted) {
        setState(() {
          _ledger = cleared;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _ledger?.entries ?? const <TuningHistoryEntry>[];
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '튜닝 기록', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: InstrumentSectionLabel(
                    'LOCAL SESSION LOG',
                    color: context.terminal.information,
                  ),
                ),
                if (entries.isNotEmpty)
                  TextButton(
                    key: const Key('clear-tuning-history'),
                    onPressed: _saving ? null : _confirmClear,
                    child: const Text('전체 삭제'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '모든 현을 맞춘 완료 시점만 이 기기에 기록합니다. 최대 100회 보관합니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
              ),
            ),
            const SizedBox(height: 18),
            if (_ledger == null && _error == null)
              const LinearProgressIndicator(minHeight: 2)
            else if (_error != null)
              _HistoryError(onRetry: _load)
            else if (entries.isEmpty)
              const _EmptyHistory()
            else
              for (var index = 0; index < entries.length; index++)
                _HistoryRow(index: index, entry: entries[index]),
          ],
        ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _error == null ? '로컬 기록' : '기록 확인 필요',
        detail: '${entries.length}/100 │ 기기 안에만 저장',
        active: _error == null,
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.index, required this.entry});

  final int index;
  final TuningHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.songTitle ?? entry.tuningName;
    final secondary = entry.songTitle == null
        ? '${entry.tuningName} · 바로 튜닝'
        : '${entry.artist ?? '아티스트 미상'} · ${entry.tuningName}';
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.terminal.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: context.instrumentType.status.copyWith(
                color: context.terminal.gridTick,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.instrumentType.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  secondary,
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
                '${entry.stringCount}현 완료 · ${_elapsedLabel(entry.elapsed)}',
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.lockHold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _timestampLabel(entry.completedAtUtc.toLocal()),
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 36),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: context.terminal.line),
        bottom: BorderSide(color: context.terminal.line),
      ),
    ),
    child: Text(
      '아직 완료한 튜닝이 없습니다.',
      textAlign: TextAlign.center,
      style: context.instrumentType.body.copyWith(
        color: context.terminal.muted,
      ),
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '로컬 튜닝 기록을 열지 못했습니다.',
        style: TextStyle(color: context.terminal.danger),
      ),
      TextButton(onPressed: onRetry, child: const Text('다시 시도')),
    ],
  );
}

String _elapsedLabel(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _timestampLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}.$month.$day  $hour:$minute';
}
