import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/work_message.dart';

void main() {
  testWidgets(
      'status messages remain reachable on compact and landscape screens',
      (tester) async {
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WorkMessage(title: '안녕하세요!', children: [
        const Text('검증 업무'),
        FilledButton(onPressed: () {}, child: const Text('작업 시작')),
      ]))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('작업 시작'));
      expect(find.text('안녕하세요!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
