import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/device_history_service.dart';
import 'package:suho_angel/widgets/device_history_chart.dart';
import 'storage_submission_test.dart' show MemoryStore;

DeviceReading reading(DateTime at,
        {int user = 31,
        String kiosk = 'pet',
        num? current = 250,
        num? capacity = 1000,
        String? error}) =>
    DeviceReading(
        userId: user,
        partner: 'partner',
        kiosk: kiosk,
        name: '페트병 수거기',
        at: at,
        current: current,
        capacity: capacity,
        error: error);

class FullStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('full');
}

void main() {
  testWidgets('chart fills a metric card column with start alignment',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 350,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('적재율 추이'),
                          DeviceHistoryChart(
                              records: [reading(DateTime(2026, 10, 27, 9))]),
                        ]))))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(DeviceHistoryChart)).width, 350);
    expect(tester.getSize(find.byType(DeviceHistoryChart)).height, 240);
    expect(tester.takeException(), isNull);
  });

  test(
      'capacity percentage distinguishes empty, unknown, full and over capacity',
      () {
    final at = DateTime.now();
    expect(reading(at, current: 0).percent, 0);
    expect(reading(at, current: 1000).percent, 100);
    expect(reading(at, current: 1250).percent, 125);
    for (final r in [
      reading(at, current: null),
      reading(at, capacity: 0),
      reading(at, current: -1),
      reading(at, error: 'offline'),
      reading(at, current: 1e308, capacity: 1e-308)
    ]) {
      expect(r.percent, isNull);
    }
  });
  test(
      'history serializes concurrent saves, isolates accounts/devices and retains failed samples',
      () async {
    final history = DeviceHistoryService(store: MemoryStore()),
        at = DateTime.now();
    await history.save(reading(at.subtract(const Duration(days: 8))));
    await Future.wait([
      history.save(reading(at)),
      history
          .save(reading(at.add(const Duration(minutes: 10)), error: 'offline')),
      history.save(reading(at, user: 42)),
      history.save(reading(at, kiosk: 'other')),
    ]);
    final rows = await history.load(31, 'partner', 'pet');
    expect(rows.length, 2);
    expect(rows.last.error, 'offline');
    expect(rows.last.percent, isNull);
    expect((await history.load(42, 'partner', 'pet')).length, 1);
    expect((await history.load(31, 'partner', 'other')).length, 1);
  });
  test(
      'polls once per ten minutes; background/resume does not backfill or overlap requests',
      () async {
    var now = DateTime(2026, 10, 19, 9), calls = 0;
    final history = DeviceHistoryService(store: MemoryStore());
    Completer<DeviceReading?>? pending = Completer<DeviceReading?>();
    final monitor = DeviceMonitor(
        history: history,
        now: () => now,
        fetch: () async {
          calls++;
          return pending != null ? pending.future : reading(now);
        });
    final first = monitor.poll();
    await monitor.poll(force: true);
    expect(calls, 1);
    pending.complete(reading(now));
    await first;
    pending = null;
    now = now.add(const Duration(minutes: 9, seconds: 59));
    await monitor.poll();
    expect(calls, 1);
    now = now.add(const Duration(seconds: 1));
    await monitor.poll(foreground: false);
    expect(calls, 1);
    now = now.add(const Duration(hours: 1));
    await monitor.poll();
    expect(calls, 2);
    expect((await history.load(31, 'partner', 'pet')).length, 2);
    monitor.dispose();
    await monitor.poll(force: true);
    expect(calls, 2);
  });
  test('failed local writes never pretend the observation was stored',
      () async {
    final monitor = DeviceMonitor(
        history: DeviceHistoryService(store: FullStore()),
        fetch: () async => reading(DateTime.now()));
    await monitor.poll();
    expect(monitor.latest!.percent, 25);
    expect(monitor.storageFailed, isTrue);
    expect(await monitor.history.load(31, 'partner', 'pet'), isEmpty);
    monitor.dispose();
  });
  testWidgets(
      'capacity chart handles unknown values, gaps, overfull and compact layouts',
      (tester) async {
    final at = DateTime.now();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 280,
                child: DeviceHistoryChart(records: [
                  reading(at),
                  reading(at.add(const Duration(minutes: 10)),
                      error: 'offline'),
                  reading(at.add(const Duration(hours: 2)), current: 1250),
                ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
