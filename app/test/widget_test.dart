import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/main.dart';

void main() {
  testWidgets('starts from song search and reaches precision tuning', (
    tester,
  ) async {
    await tester.pumpWidget(const ToaunerApp());

    expect(find.text('곡명 또는 아티스트 검색'), findsOneWidget);
    expect(find.text('정밀 튜닝 시작'), findsOneWidget);

    await tester.ensureVisible(find.text('정밀 튜닝 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정밀 튜닝 시작'));
    await tester.pumpAndSettle();

    expect(find.text('마이크 연결 전 · DSP 기준선 준비 완료'), findsOneWidget);
  });
}
