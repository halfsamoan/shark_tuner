import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/ui/throttled_live_region.dart';

void main() {
  testWidgets('announces only the latest label at most once per second', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: ThrottledLiveRegion(label: '첫 상태', child: Text('visual')),
      ),
    );
    expect(find.bySemanticsLabel('첫 상태'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: ThrottledLiveRegion(label: '중간 상태', child: Text('visual')),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: ThrottledLiveRegion(label: '최신 상태', child: Text('visual')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.bySemanticsLabel('첫 상태'), findsOneWidget);
    expect(find.bySemanticsLabel('중간 상태'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.bySemanticsLabel('최신 상태'), findsOneWidget);
    semantics.dispose();
  });
}
