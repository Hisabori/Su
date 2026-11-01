import 'package:flutter/material.dart';
import 'package:suho_angel/widgets/feature_card.dart';
import 'package:suho_angel/widgets/app_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/widgets/work_home_panel.dart';

void main() {
  testWidgets('feature card keeps one named action and respects reduced motion',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.darkTheme(),
        home: MediaQuery(
            data: const MediaQueryData(
                disableAnimations: true,
                highContrast: true,
                textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 280,
                        child: FeatureCard(
                            label: '수거기 기록',
                            description: '적재율 그래프와 조회 기록을 한눈에',
                            kind: AppIconKind.collector,
                            onTap: () => taps++)))))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('수거기 기록'), findsOneWidget);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(FeatureCard)));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home uses server assignment and preserves start restrictions',
      (tester) async {
    final info = WorkInfo(
        id: '1',
        name: '서버 근무',
        startTime: '09:30',
        endTime: '12:30',
        steps: [WorkStep(id: '1', name: '확인', prompt: '확인')]);
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: Scaffold(
            body: WorkHomePanel(
          info: info,
          name: '서버 이름',
          onStart: null,
          waitText: '작업 시작까지 10:00',
          onCollector: () {},
          onCommunity: () {},
          onHistory: () {},
        ))));
    await tester.pumpAndSettle();
    expect(find.text('서버 근무'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.textContaining('서버 이름'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
  testWidgets(
      'large text home keeps shortcut actions reachable without invented times',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var history = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 568), textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: WorkHomePanel(
                  info: WorkInfo(id: '1', name: '오늘의 배정'),
                  name: null,
                  onStart: () {},
                  onCollector: () {},
                  onCommunity: () {},
                  onHistory: () => history++)),
        )));
    await tester.pumpAndSettle();
    expect(find.text('근무 시간 정보가 없습니다.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('내 근무기록'), 250);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('내 근무기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 근무기록'));
    expect(history, 1);
    expect(tester.takeException(), isNull);
  });
}
