import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/models/work_result.dart';
import 'package:suho_angel/models/work_hours.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/widgets/completion_panel.dart';
import 'package:suho_angel/screens/result_log_screen.dart';

void main() {
  test('server shift is separate from response time and supports overnight',
      () {
    final day = DateTime(2026, 11, 15);
    final hours = WorkHours.forWork(
        WorkInfo(
            id: '8', name: '업무', startTime: '09:00:00', endTime: '12:00:00'),
        day);
    expect(hours.start, DateTime(2026, 11, 15, 9));
    expect(hours.end, DateTime(2026, 11, 15, 12));
    expect(WorkHours.fromRecord(hours.snapshot).durationLabel, '3시간');
    final overnight = WorkHours.forWork(
        WorkInfo(id: '8', name: '업무', startTime: '23:00', endTime: '02:00'),
        day);
    expect(overnight.end, DateTime(2026, 11, 16, 2));
    expect(overnight.durationLabel, '3시간');
    expect(WorkHours.forWork(WorkInfo(id: '8', name: '업무'), day).durationLabel,
        '미확인');
  });
  testWidgets('completion shows server hours with response times in details',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CompletionPanel(
      name: '검증',
      serverHours: true,
      start: DateTime(2026, 11, 15, 9),
      end: DateTime(2026, 11, 15, 12),
      activityStart: DateTime(2026, 11, 15, 9, 12),
      activityEnd: DateTime(2026, 11, 15, 9, 16),
      onHistory: () {},
      onCheckout: () {},
      onDevice: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('오전 9:00', findRichText: true), findsOneWidget);
    expect(find.textContaining('오후 12:00', findRichText: true), findsOneWidget);
    await tester.ensureVisible(find.text('앱 작업 시각'));
    await tester.tap(find.text('앱 작업 시각'));
    await tester.pumpAndSettle();
    expect(find.text('응답 시작: 오전 9:12'), findsOneWidget);
    expect(find.text('응답 완료: 오전 9:16'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('missing cached server hours are filled when the server supplies them',
      () {
    final cached = WorkHours.fromRecord({
      'schedule_source': 'server',
      'scheduled_start_at': null,
      'scheduled_end_at': null
    });
    final fresh =
        WorkHours(DateTime(2026, 11, 15, 9), DateTime(2026, 11, 15, 12));
    expect(cached.isComplete, isFalse);
    expect(cached.fillMissing(fresh).durationLabel, '3시간');
    final partial = WorkHours(DateTime(2026, 11, 15, 8), null);
    expect(partial.fillMissing(fresh).start!.hour, 8);
    expect(partial.fillMissing(fresh).end!.hour, 12);
  });
  testWidgets(
      'missing schedule shows an explanation and refresh instead of an unknown range',
      (tester) async {
    var refreshed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CompletionPanel(
      name: '검증',
      serverHours: true,
      start: null,
      end: null,
      onRefreshHours: () => refreshed = true,
      onHistory: () {},
      onCheckout: () {},
      onDevice: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('근무시간 확인이 필요해요'), findsOneWidget);
    expect(find.textContaining('시각 미확인', findRichText: true), findsNothing);
    await tester.ensureVisible(find.text('근무시간 다시 확인'));
    await tester.tap(find.text('근무시간 다시 확인'));
    expect(refreshed, isTrue);
    expect(tester.takeException(), isNull);
  });
  test('UTC and local representations produce the same work API clock', () {
    final utc = DateTime.parse('2026-11-15T00:15:00Z');
    expect(formatDateTime(utc), formatDateTime(utc.toLocal()));
    expect(formatDate(utc), formatDate(utc.toLocal()));
    expect(completionTime(utc), completionTime(utc.toLocal()));
  });
  testWidgets('completed work and its history agree after restoring UTC values',
      (tester) async {
    final end = DateTime.now().toUtc(),
        start = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final expected = completionTime(start.toLocal());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CompletionPanel(
                name: '시간 검증',
                start: start,
                end: end,
                onHistory: () {},
                onCheckout: () {},
                onDevice: () {}))));
    await tester.pumpAndSettle();
    expect(find.textContaining(expected, findRichText: true), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: ResultLogScreen(readOnlyRecords: [
      {
        'work_name': '시간 검증',
        'started_at': start.toIso8601String(),
        'scheduled_start_at': start.toIso8601String(),
        'scheduled_end_at': end.toIso8601String(),
        'ended_at': end.toIso8601String(),
        'server_submitted': true,
      }
    ])));
    await tester.pumpAndSettle();
    expect(find.textContaining(expected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
