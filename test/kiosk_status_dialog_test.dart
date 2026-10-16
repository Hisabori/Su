import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/kiosk_status_dialog.dart';

void main() {
  testWidgets(
      'kiosk receipt matches API values and closes without altering work',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const KioskStatusDialog(
                            name: '수호천사05',
                            status: '비어있음',
                            current: 0,
                            capacity: 1000)),
                    child: const Text('현황'))))));
    await tester.tap(find.text('현황'));
    await tester.pumpAndSettle();
    expect(find.text('키오스크 현황'), findsOneWidget);
    expect(find.text('0.0%  (0/1000)'), findsOneWidget);
    expect(find.text('비어있음'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('키오스크 현황'), findsNothing);
  });

  testWidgets(
      'unknown capacity never appears as an empty kiosk and long names fit',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: KioskStatusDialog(
                name: '이름이 아주 긴 키오스크 기기',
                status: '상태 미확인',
                current: null,
                capacity: 0))));
    await tester.pumpAndSettle();
    expect(find.text('용량 미확인'), findsOneWidget);
    expect(find.textContaining('0.0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
