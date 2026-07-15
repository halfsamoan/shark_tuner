import 'package:flutter/material.dart';

import '../app/app_preferences.dart';
import '../app/instrument_theme.dart';
import '../ui/instrument_surface.dart';
import '../ui/instrument_widgets.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.appPreferences;
    final preferences = controller.value;
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '설정', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('화면과 튜너 동작', style: context.instrumentType.title),
            const SizedBox(height: 6),
            Text(
              '선택은 이 기기에 저장됩니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const InstrumentSectionLabel('테마'),
            const SizedBox(height: 10),
            for (final themeId in SharkTuneThemeId.values) ...[
              ThemeTile(
                themeId: themeId,
                selected: preferences.themeId == themeId,
                onTap: () => controller.setTheme(themeId),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            const InstrumentSectionLabel('튜너 허용치'),
            const SizedBox(height: 10),
            InstrumentSurface(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    for (final mode in TunerToleranceMode.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: mode == TunerToleranceMode.beginner ? 6 : 0,
                            left: mode == TunerToleranceMode.pro ? 6 : 0,
                          ),
                          child: mode == preferences.toleranceMode
                              ? FilledButton(
                                  key: Key('tolerance-${mode.name}'),
                                  onPressed: () =>
                                      controller.setToleranceMode(mode),
                                  child: Text(mode.label),
                                )
                              : OutlinedButton(
                                  key: Key('tolerance-${mode.name}'),
                                  onPressed: () =>
                                      controller.setToleranceMode(mode),
                                  child: Text(mode.label),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preferences.toleranceMode == TunerToleranceMode.beginner
                  ? '빠른 ±2¢ 잠금 후 ±5¢ 범위를 유지합니다.'
                  : '빠른 ±2¢ 잠금 후 ±2¢ 범위를 유지합니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const InstrumentSectionLabel('편의'),
            const SizedBox(height: 8),
            SettingToggleRow(
              rowKey: const Key('haptics-toggle'),
              label: '햅틱',
              detail: '현 잠금과 완료를 진동으로 알림',
              value: preferences.hapticsEnabled,
              onChanged: controller.setHapticsEnabled,
            ),
            SettingToggleRow(
              rowKey: const Key('reduce-motion-toggle'),
              label: '모션 줄이기',
              detail: '전환과 락 효과를 즉시 표시',
              value: preferences.reduceMotion,
              onChanged: controller.setReduceMotion,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const InstrumentStatusBar(
        state: '설정 저장됨',
        detail: '이 기기',
      ),
    );
  }
}

class ThemeTile extends StatelessWidget {
  const ThemeTile({
    super.key,
    required this.themeId,
    required this.selected,
    required this.onTap,
  });

  final SharkTuneThemeId themeId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = SharkTuneThemes.values[themeId]!;
    return Semantics(
      button: true,
      selected: selected,
      label: '${themeId.label} 테마${selected ? ', 선택됨' : ''}',
      child: InkWell(
        key: Key('theme-${themeId.name}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.terminal.panel,
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? context.terminal.accent : context.terminal.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preview.canvas,
                  border: Border.all(color: preview.line),
                ),
                alignment: Alignment.center,
                child: Container(width: 18, height: 3, color: preview.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      themeId.label,
                      style: context.instrumentType.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      themeId.description,
                      style: context.instrumentType.caption.copyWith(
                        color: context.terminal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                selected ? '선택됨' : '선택',
                style: context.instrumentType.status.copyWith(
                  color: selected
                      ? context.terminal.accent
                      : context.terminal.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingToggleRow extends StatelessWidget {
  const SettingToggleRow({
    super.key,
    required this.rowKey,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.terminal.line)),
      ),
      child: SwitchListTile(
        key: rowKey,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: context.instrumentType.body),
        subtitle: Text(
          detail,
          style: context.instrumentType.caption.copyWith(
            color: context.terminal.textSecondary,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
