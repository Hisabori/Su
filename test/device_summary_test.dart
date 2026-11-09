import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/utils/device_summary.dart';
import 'package:suho_angel/widgets/device_summary_card.dart';
import 'device_history_test.dart' show reading;

void main() {
  test(
      'summary excludes unknown samples and retains real zero and overcapacity',
      () {
    final now = DateTime.now();
    final summary = DevicePeriodSummary([
      reading(now, current: 0),
      reading(now, current: 1250),
      reading(now, error: 'offline'),
      reading(now, capacity: 0),
    ]);
    expect(summary.valid, 2);
    expect(summary.unknown, 2);
    expect(summary.average, 62.5);
    expect(summary.maximum, 125);
    expect(DevicePeriodSummary([]).average, isNull);
    expect(DevicePeriodSummary.percent(null), '측정 전');
    final extreme = DevicePeriodSummary([
      reading(now, current: 1e308, capacity: 100),
      reading(now, current: 1e308, capacity: 100),
    ]);
    expect(extreme.average!.isFinite, isTrue);
  });
  test('periods use local day or exact past seven days without future records',
      () {
    final now = DateTime(2026, 11, 8, 12);
    final records = [
      reading(now.subtract(const Duration(days: 8))),
      reading(now.subtract(const Duration(days: 7))),
      reading(DateTime(2026, 11, 8)),
      reading(now),
      reading(now.add(const Duration(seconds: 1))),
    ];
    expect(devicePeriodReadings(records, now: now, week: false).length, 2);
    expect(devicePeriodReadings(records, now: now, week: true).length, 3);
    expect(records.length, 5);
  });
  testWidgets('summary fits narrow dark screens with large text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.darkTheme(),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: SizedBox(
                        width: 280,
                        child: DeviceSummaryCard(
                            summary:
                                DevicePeriodSummary([reading(DateTime.now())]),
                            week: true)))))));
    await tester.pumpAndSettle();
    expect(find.text('최근 7일 한눈에'), findsOneWidget);
    expect(find.text('25.0%'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
