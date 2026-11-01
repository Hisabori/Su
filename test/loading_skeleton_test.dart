import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/widgets/loading_skeleton.dart';

void main() {
  testWidgets(
      'skeleton settles, announces once and fits large text in dark mode',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final layout in SkeletonLayout.values) {
      await tester.pumpWidget(MaterialApp(
          theme: AppStyle.darkTheme(),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: LoadingSkeleton(
                      key: ValueKey(layout),
                      label: '기록을 불러오고 있어요.',
                      layout: layout)))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('기록을 불러오고 있어요.'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('reduced motion renders full opacity immediately',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true, highContrast: true),
            child: Scaffold(body: LoadingSkeleton(label: '불러오는 중')))));
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
