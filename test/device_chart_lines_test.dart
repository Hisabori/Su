import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/widgets/device_history_chart.dart';
import 'device_history_test.dart' show reading;

void main() {
  testWidgets('chart tap exposes a reading and unknown values stay unknown',
      (tester) async {
    final at = DateTime(2026, 11, 17, 9);
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(),
        home: Scaffold(
            body: SizedBox(
                width: 320,
                child: DeviceHistoryChart(
                    records: [reading(at, error: 'offline')])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('그래프를 누르면'), findsOneWidget);
    await tester.tap(find.byType(CustomPaint).last);
    await tester.pump();
    expect(find.text('11/17 09:00 · 용량 미확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'chart connects measurements and draws a distinct bridge across missing periods',
      (tester) async {
    final at = DateTime.now();
    for (final gap in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          theme: AppStyle.theme(),
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 320,
                      child: DeviceHistoryChart(records: [
                        reading(at.add(Duration(minutes: gap ? 60 : 10)),
                            current: 500),
                        if (gap)
                          reading(at.add(const Duration(minutes: 30)),
                              error: '미확인'),
                        reading(at, current: 250),
                      ]))))));
      await tester.pumpAndSettle();
      final chart = find.descendant(
          of: find.byType(DeviceHistoryChart),
          matching: find.byType(CustomPaint));
      expect(
          chart,
          paints
            ..line()
            ..line()
            ..line()
            ..line(color: AppStyle.coral.withValues(alpha: gap ? 0.7 : 1.0)));
      expect(tester.takeException(), isNull);
    }
  });
}
