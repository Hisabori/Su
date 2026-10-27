import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/question_panel.dart';
import 'package:suho_angel/theme/app_style.dart';

void main() {
  testWidgets('large text on a narrow phone keeps question actions readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var answers = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: QuestionPanel(
              prompt: '오늘 근무를 도와주실 근로지원인이 있으신가요?',
              current: 5,
              total: 19,
              speaking: false,
              listening: false,
              onReplay: () {},
              onSpeech: () {},
              onYes: () => answers++,
              onNo: () {},
              onSettings: () {},
              onDevice: () {},
            )))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('예'));
    await tester.tap(find.text('예'));
    expect(answers, 1);
    expect(tester.takeException(), isNull);
  });

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
  testWidgets('video shares question card without manual answer shortcuts',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: QuestionPanel(
        prompt: '영상을 시청해 주세요.',
        current: 9,
        total: 19,
        speaking: false,
        listening: false,
        media:
            const SizedBox(height: 160, child: ColoredBox(color: Colors.blue)),
        mediaStatus: '영상을 확인해 주세요.',
        onReplay: () {},
        onSpeech: () {},
        onYes: () {},
        onNo: () {},
        onSettings: () {},
        onDevice: () {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('질문 9 / 19'), findsOneWidget);
      expect(find.text('예'), findsNothing);
      expect(find.text('아니요'), findsNothing);
      expect(find.text('영상을 확인해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
