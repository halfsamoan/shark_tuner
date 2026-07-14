import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/instrument_theme.dart';
import 'package:toauner_app/src/settings/app_information_screen.dart';

void main() {
  testWidgets('states the on-device microphone and offline data contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInstrumentTheme(),
        home: const AppInformationScreen(),
      ),
    );

    expect(find.text('개인정보 및 앱 정보'), findsOneWidget);
    expect(find.textContaining('녹음 파일로 저장하지 않습니다'), findsOneWidget);
    expect(find.textContaining('서버로 보내지 않습니다'), findsOneWidget);
    expect(find.textContaining('오프라인 데이터'), findsOneWidget);
    expect(find.byKey(const Key('open-source-licenses')), findsOneWidget);
  });

  testWidgets('remains usable at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          theme: buildInstrumentTheme(),
          home: const AppInformationScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byKey(const Key('open-source-licenses')), findsOneWidget);
  });
}
