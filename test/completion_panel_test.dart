import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/completion_panel.dart';

void main() {
  test('Korean completion times distinguish noon, midnight and minutes', () {
    expect(completionTime(DateTime(2026, 10, 16, 9)), '오전 9:00');
    expect(completionTime(DateTime(2026, 10, 16, 12)), '오후 12:00');
    expect(completionTime(DateTime(2026, 10, 16, 0, 7)), '오전 12:07');
  });
  testWidgets(
      'reference completion retains both actions on narrow and landscape screens',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var history = 0, checkout = 0;
    for (final size in [
      const Size(390, 844),
      const Size(320, 568),
      const Size(844, 390)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CompletionPanel(
        name: '테스트 사용자',
        start: DateTime(2026, 10, 16, 9),
        end: DateTime(2026, 10, 16, 12),
        onHistory: () => history++,
        onCheckout: () => checkout++,
        onDevice: () {},
      ))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('근무기록 자세히 보기'));
      await tester.tap(find.text('근무기록 자세히 보기'));
      await tester.ensureVisible(find.text('퇴근하기'));
      await tester.tap(find.text('퇴근하기'));
      expect(tester.takeException(), isNull);
    }
    expect(history, 3);
    expect(checkout, 3);
  });
}
