import 'package:suho_angel/widgets/work_home_panel.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/widgets/glass_action_bar.dart';
import 'package:suho_angel/widgets/app_icon.dart';

void main() {
  testWidgets(
      'work start remains operable after portrait landscape portrait with the floating bar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: Scaffold(
          body: WorkHomePanel(
              info: WorkInfo(
                  id: '8',
                  name: '호환 검증',
                  steps: [WorkStep(id: '1', name: '확인', prompt: '확인')]),
              name: '검증',
              onStart: () {
                starts++;
              },
              onCollector: () {},
              onCommunity: () {},
              onHistory: () {}),
          bottomNavigationBar: GlassActionBar(actions: [
            (label: '기기 상태', icon: AppIconKind.collector, onPressed: () {}),
            (label: '커뮤니티', icon: AppIconKind.community, onPressed: () {}),
            (label: '작업 기록', icon: AppIconKind.history, onPressed: () {}),
          ]),
        )));
    await tester.pumpAndSettle();
    for (final size in [const Size(844, 390), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('작업 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('작업 시작'));
      expect(tester.takeException(), isNull);
    }
    expect(starts, 2);
  });

  testWidgets(
      'floating actions remain reachable with large text on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: const Text('홈'),
              bottomNavigationBar: GlassActionBar(actions: [
                (
                  label: '기기 상태',
                  icon: AppIconKind.collector,
                  onPressed: () {
                    calls++;
                  }
                ),
                (
                  label: '커뮤니티',
                  icon: AppIconKind.community,
                  onPressed: () {
                    calls++;
                  }
                ),
                (
                  label: '작업 기록',
                  icon: AppIconKind.history,
                  onPressed: () {
                    calls++;
                  }
                ),
              ])),
        )));
    await tester.pumpAndSettle();
    for (final label in ['기기 상태', '커뮤니티', '작업 기록']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
}
