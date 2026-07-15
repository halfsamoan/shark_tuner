import 'package:flutter/material.dart';

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
            InstrumentActionRow(
              rowKey: const Key('metronome-entry'),
              label: '메트로놈',
              detail: '박자와 템포',
              onTap: onMetronome,
            ),
            InstrumentActionRow(
              rowKey: const Key('tuning-history-entry'),
              label: '튜닝 기록',
              detail: historyCount == 0 ? '완료 기록 없음' : '$historyCount회 완료',
              onTap: onHistory,
            ),
            InstrumentActionRow(
              rowKey: const Key('string-care-entry'),
              label: '줄 관리',
              detail: '설치일과 교체 주기',
              onTap: onStringCare,
            ),
            InstrumentActionRow(
              rowKey: const Key('settings-entry'),
              label: '설정',
              detail: '테마와 튜너 동작',
              onTap: onSettings,
            ),
            InstrumentActionRow(
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
