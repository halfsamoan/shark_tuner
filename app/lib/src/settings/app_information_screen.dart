import 'package:flutter/material.dart';

import '../app/instrument_theme.dart';
import '../ui/instrument_widgets.dart';

class AppInformationScreen extends StatelessWidget {
  const AppInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InstrumentHeaderBar(section: '개인정보 및 앱 정보', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '소리는 밖으로 나가지 않습니다.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'toauner는 기타 소리를 기기 안에서 실시간으로 분석합니다.',
                  style: InstrumentTypeTheme.standard.body.copyWith(
                    color: InstrumentColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                const _InformationSection(
                  label: '마이크',
                  title: '튜닝할 때만 듣습니다',
                  body:
                      '정밀 튜너와 안정성 검사를 사용하는 동안에만 마이크 입력을 처리합니다. '
                      '소리를 녹음 파일로 저장하지 않습니다. 서버로 보내지 않습니다. '
                      '광고나 사용자 추적에 사용하지 않습니다.',
                ),
                const _InformationSection(
                  label: '곡 데이터',
                  title: '검색은 오프라인으로 동작합니다',
                  body:
                      '곡명, 아티스트, 튜닝, 카포처럼 튜닝에 필요한 정보는 앱에 포함된 오프라인 데이터에서 찾습니다. '
                      '가사, 악보, 탭은 저장하지 않습니다.',
                ),
                const _InformationSection(
                  label: '줄 교체 기록',
                  title: '설치일은 이 기기에만 저장합니다',
                  body:
                      '사용자가 입력한 줄 설치일, 점검 주기, 게이지와 튜닝 식별자는 앱 전용 저장 공간에 보관합니다. '
                      '서버로 보내지 않으며 줄 관리 화면에서 기록을 모두 지울 수 있습니다.',
                ),
                const _InformationSection(
                  label: '정확도',
                  title: '환경에 따라 나누어 검증합니다',
                  body:
                      '합성 신호, 녹음된 실기타, 휴대전화 마이크 입력은 서로 다른 기준으로 측정합니다. '
                      '신호가 약하거나 주변 소음이 크면 맞는 척하지 않고 다시 튕겨 달라고 안내합니다.',
                ),
                const _InformationSection(
                  label: '접근성',
                  title: '화면과 소리 없이도 상태를 전합니다',
                  body:
                      '튜너 상태는 TalkBack으로 읽을 수 있고, 시스템 글자 크기를 따릅니다. '
                      '튜닝 완료는 화면 변화와 진동으로 함께 알립니다.',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('open-source-licenses'),
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'toauner',
                      applicationLegalese: '오픈소스 구성요소와 글꼴 라이선스',
                    ),
                    child: const Text('오픈소스 라이선스 보기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const InstrumentStatusBar(
        state: '기기 안에서 처리',
        detail: '녹음·전송 없음',
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 22),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: InstrumentColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InstrumentSectionLabel(label, color: InstrumentColors.information),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            body,
            style: InstrumentTypeTheme.standard.body.copyWith(
              color: InstrumentColors.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
