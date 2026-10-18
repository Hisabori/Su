import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/screens/result_log_screen.dart';

void main() {
  testWidgets(
      'today retains old unconfirmed records; all shows older saved history',
      (tester) async {
    final old =
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    await tester.pumpWidget(MaterialApp(
        home: ResultLogScreen(readOnlyRecords: [
      {'work_name': '예전 저장 기록', 'ended_at': old, 'server_submitted': true},
      {
        'work_name': '미확인 기록',
        'ended_at': old,
        'server_submitted': false,
        'answers': ['invalid', null]
      },
    ])));
    await tester.pumpAndSettle();
    expect(find.text('예전 저장 기록'), findsNothing);
    expect(find.text('미확인 기록'), findsOneWidget);
    expect(find.byTooltip('결과 재전송'), findsNothing);
    await tester.tap(find.text('답변 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('일일 근무 성과'), findsOneWidget);
    await tester.tap(find.text('확인했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    expect(find.text('예전 저장 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
