import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/question_panel.dart';

void main() {
  testWidgets(
      'reference question layout fits compact and landscape screens and routes answers',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var yes = 0;
    for (final size in [
      const Size(390, 844),
      const Size(320, 568),
      const Size(844, 390)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: QuestionPanel(
        prompt: '오늘 근무를 도와주실 근로지원인이 있으신가요?',
        current: 5,
        total: 19,
        speaking: false,
        listening: true,
        onReplay: () {},
        onSpeech: () {},
        onYes: () => yes++,
        onNo: () {},
        onSettings: () {},
        onDevice: () {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('질문 5 / 19'), findsOneWidget);
      expect(find.text('+14 남음'), findsOneWidget);
      expect(find.text('답변 듣는중…'), findsOneWidget);
      await tester.ensureVisible(find.text('예'));
      await tester.tap(find.text('예'));
      expect(tester.takeException(), isNull);
    }
    expect(yes, 3);
  });
}
