import 'dart:async';

import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';
import 'string_care_model.dart';
import 'string_care_store.dart';

class StringCareScreen extends StatefulWidget {
  const StringCareScreen({
    super.key,
    this.loader = loadStringCareLedger,
    this.saver = saveStringCareLedger,
    this.now = DateTime.now,
    this.suggestedGaugeLabel,
    this.suggestedTuningId,
  });

  final StringCareLoader loader;
  final StringCareSaver saver;
  final DateTime Function() now;
  final String? suggestedGaugeLabel;
  final String? suggestedTuningId;

  @override
  State<StringCareScreen> createState() => _StringCareScreenState();
}

class _StringCareScreenState extends State<StringCareScreen> {
  late final TextEditingController _gaugeController;
  var _ledger = StringCareLedger.empty();
  late DateTime _installedOn;
  var _loading = true;
  var _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final now = widget.now();
    _installedOn = DateTime(now.year, now.month, now.day);
    _gaugeController = TextEditingController(
      text: widget.suggestedGaugeLabel ?? '',
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ledger = await widget.loader();
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _loading = false;
          _error = null;
        });
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

  Future<void> _persist(StringCareLedger next, {String? confirmation}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.saver(next);
      if (!mounted) return;
      setState(() {
        _ledger = next;
        _saving = false;
      });
      if (confirmation != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(confirmation)));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _ledger.statusOn(widget.now());
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '줄 관리', showBack: true),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                children: [
                  InstrumentSectionLabel(
                    'String life log',
                    color: context.terminal.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '줄을 바꾼 날부터\n다음 점검까지',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '줄 수명은 연주 시간·땀·보관 환경에 따라 달라집니다. 아래 주기는 사용자가 정한 점검 알림이며 제조사 수명 판정이 아닙니다.',
                    style: context.instrumentType.caption.copyWith(
                      color: context.terminal.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CurrentStringStatus(status: status),
                  const SizedBox(height: 24),
                  InstrumentSectionLabel('01  /  점검 알림 주기'),
                  const SizedBox(height: 8),
                  _ReminderIntervalSelector(
                    selectedDays: _ledger.reminderIntervalDays,
                    enabled: !_saving,
                    onSelected: (days) => _persist(
                      _ledger.withReminderIntervalDays(days),
                      confirmation: '점검 알림을 $days일로 저장했습니다.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  InstrumentSectionLabel('02  /  새 줄 설치 기록'),
                  const SizedBox(height: 8),
                  _DateRow(
                    date: _installedOn,
                    enabled: !_saving,
                    onTap: _pickInstalledOn,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _gaugeController,
                    enabled: !_saving,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: '현 게이지 또는 세트 이름 (선택)',
                      hintText: '예: 11–56',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('record-string-installation'),
                      onPressed: _saving ? null : _recordInstallation,
                      child: const Text('새 줄 설치 기록'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '저장하지 못했습니다. 기기 저장 공간을 확인하고 다시 시도해 주세요.',
                      style: context.instrumentType.caption.copyWith(
                        color: context.terminal.amber,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: InstrumentSectionLabel('03  /  교체 기록')),
                      if (_ledger.installations.isNotEmpty)
                        TextButton(
                          key: const Key('clear-string-care-history'),
                          onPressed: _saving ? null : _confirmClearHistory,
                          child: const Text('모두 지우기'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_ledger.installations.isEmpty)
                    Text(
                      '아직 저장된 교체 기록이 없습니다.',
                      style: context.instrumentType.caption.copyWith(
                        color: context.terminal.muted,
                      ),
                    )
                  else
                    for (final record in _ledger.installations)
                      _HistoryRow(record: record),
                ],
              ),
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _statusBarText(status),
        detail: '${_ledger.reminderIntervalDays}일 점검 주기',
        active: status.kind != StringCareStatusKind.noRecord,
      ),
    );
  }

  Future<void> _pickInstalledOn() async {
    final now = widget.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _installedOn,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      lastDate: today,
      helpText: '줄 설치일',
    );
    if (selected != null && mounted) {
      setState(() => _installedOn = selected);
    }
  }

  Future<void> _recordInstallation() async {
    final now = widget.now();
    final next = _ledger.recordInstallation(
      id: 'strings-${now.toUtc().microsecondsSinceEpoch}',
      installedOn: _installedOn,
      recordedAtUtc: now.toUtc(),
      gaugeLabel: _gaugeController.text,
      tuningId: widget.suggestedTuningId,
    );
    await _persist(next, confirmation: '줄 설치일을 기기에 저장했습니다.');
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('교체 기록을 모두 지울까요?'),
        content: const Text('기기에 저장된 설치일과 게이지 기록이 삭제됩니다. 알림 주기는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-clear-string-care'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _persist(
        _ledger.clearInstallations(),
        confirmation: '줄 교체 기록을 모두 지웠습니다.',
      );
    }
  }
}

class _CurrentStringStatus extends StatelessWidget {
  const _CurrentStringStatus({required this.status});

  final StringCareStatus status;

  @override
  Widget build(BuildContext context) {
    final warning =
        status.kind == StringCareStatusKind.due ||
        status.kind == StringCareStatusKind.overdue;
    return Semantics(
      liveRegion: true,
      label: _statusText(status),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.terminal.panel,
          border: Border.all(
            color: warning ? context.terminal.amber : context.terminal.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              warning
                  ? '!'
                  : status.kind == StringCareStatusKind.noRecord
                  ? '○'
                  : '●',
              style: context.instrumentType.subhead.copyWith(
                color: warning
                    ? context.terminal.amber
                    : context.terminal.accent,
                fontFamily: 'IBM Plex Mono',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusText(status),
                    style: context.instrumentType.body.copyWith(
                      color: warning
                          ? context.terminal.amber
                          : context.terminal.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (status.gaugeLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      status.gaugeLabel!,
                      style: context.instrumentType.status.copyWith(
                        color: context.terminal.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderIntervalSelector extends StatelessWidget {
  const _ReminderIntervalSelector({
    required this.selectedDays,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedDays;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final days in StringCareLedger.supportedReminderIntervals)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                button: true,
                selected: selectedDays == days,
                label: '$days일 점검 알림',
                child: InkWell(
                  key: Key('string-care-interval-$days'),
                  onTap: enabled ? () => onSelected(days) : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedDays == days
                          ? context.terminal.accent
                          : context.terminal.panel,
                      border: Border.all(
                        color: selectedDays == days
                            ? context.terminal.accent
                            : context.terminal.line,
                      ),
                    ),
                    child: Text(
                      '$days일',
                      style: context.instrumentType.status.copyWith(
                        color: selectedDays == days
                            ? context.terminal.accentInk
                            : context.terminal.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('string-care-install-date'),
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.terminal.panel,
          border: Border.all(color: context.terminal.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '설치일  ${_formatDate(date)}',
                style: context.instrumentType.body,
              ),
            ),
            Text(
              '변경',
              style: context.instrumentType.status.copyWith(
                color: context.terminal.information,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final StringInstallationRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.terminal.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _formatDate(record.installedOn),
              style: context.instrumentType.status.copyWith(
                color: context.terminal.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              record.gaugeLabel ?? '게이지 기록 없음',
              style: context.instrumentType.caption,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusText(StringCareStatus status) {
  return switch (status.kind) {
    StringCareStatusKind.noRecord => '설치 기록 없음',
    StringCareStatusKind.fresh || StringCareStatusKind.dueSoon =>
      '현재 줄 ${status.ageDays}일째 · 교체 알림 D-${status.daysUntilReminder}',
    StringCareStatusKind.due => '현재 줄 ${status.ageDays}일째 · 오늘 교체 알림',
    StringCareStatusKind.overdue =>
      '현재 줄 ${status.ageDays}일째 · 교체 알림 ${-status.daysUntilReminder!}일 지남',
  };
}

String _statusBarText(StringCareStatus status) {
  return switch (status.kind) {
    StringCareStatusKind.noRecord => '줄 기록 대기',
    StringCareStatusKind.fresh => '줄 상태 기록됨',
    StringCareStatusKind.dueSoon => '교체 점검 예정',
    StringCareStatusKind.due => '오늘 교체 점검',
    StringCareStatusKind.overdue => '교체 점검 지남',
  };
}

String _formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
