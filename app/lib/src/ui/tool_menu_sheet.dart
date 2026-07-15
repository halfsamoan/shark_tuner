import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';
import 'instrument_widgets.dart';

class ToolMenuSheet extends StatelessWidget {
  const ToolMenuSheet({
    super.key,
    required this.historyCount,
    required this.onMetronome,
    required this.onHistory,
    required this.onStringCare,
    required this.onSettings,
    required this.onInformation,
  });

  final int historyCount;
  final VoidCallback onMetronome;
  final VoidCallback onHistory;
  final VoidCallback onStringCare;
  final VoidCallback onSettings;
  final VoidCallback onInformation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InstrumentSectionLabel('도구'),
            const SizedBox(height: 10),
            ToolMenuRow(
              rowKey: const Key('metronome-entry'),
              label: '메트로놈',
              detail: '박자와 템포',
              onTap: onMetronome,
            ),
            ToolMenuRow(
              rowKey: const Key('tuning-history-entry'),
              label: '튜닝 기록',
              detail: historyCount == 0 ? '완료 기록 없음' : '$historyCount회 완료',
              onTap: onHistory,
            ),
            ToolMenuRow(
              rowKey: const Key('string-care-entry'),
              label: '줄 관리',
              detail: '설치일과 교체 주기',
              onTap: onStringCare,
            ),
            ToolMenuRow(
              rowKey: const Key('settings-entry'),
              label: '설정',
              detail: '테마와 튜너 동작',
              onTap: onSettings,
            ),
            ToolMenuRow(
              rowKey: const Key('app-information'),
              label: '개인정보 및 앱 정보',
              detail: '기기 내 처리 원칙',
              onTap: onInformation,
            ),
          ],
        ),
      ),
    );
  }
}

class ToolMenuRow extends StatelessWidget {
  const ToolMenuRow({
    super.key,
    required this.rowKey,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $detail',
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.terminal.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.instrumentType.body),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: context.instrumentType.caption.copyWith(
                        color: context.terminal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '›',
                style: context.instrumentType.subhead.copyWith(
                  color: context.terminal.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
