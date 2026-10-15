import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/models/work_result.dart';
import 'package:suho_angel/models/work_schedule.dart';

void main() {
  test('result JSON uses recovered Korean keys and serialized JSON string', () {
    final start = DateTime(2026, 10, 15, 8);
    final end = start.add(const Duration(seconds: 61));
    final result = WorkResultPayload(
        work: WorkInfo(id: '9', name: '작업', processVersionId: 12),
        userId: 42,
        start: start,
        end: end,
        restSeconds: 0,
        deviceChecks: [],
        answers: [
          {
            'step_id': '3',
            'answer': 'yes',
            'started_at': start.toIso8601String(),
            'ended_at': end.toIso8601String(),
            'work_seconds': 61
          }
        ]);
    expect(result.request['process_version_id'], 12);
    expect(result.request['work_minutes'], 2);
    expect(result.request['work_date'], '2026-10-15');
    expect(jsonDecode(result.request['result_json'] as String), [
      {
        'stepid': 3,
        '시작시간': '2026-10-15 08:00:00',
        '종료시간': '2026-10-15 08:01:01',
        '시간': 2,
        '비고': 1
      }
    ]);
  });
  test('rest windows preserve boundaries and resume against wall time', () {
    final anchor = DateTime(2026, 10, 15, 8);
    expect(
        WorkSchedule.restAt(
            anchor, anchor.add(const Duration(minutes: 49)), 50, 10),
        isNull);
    final rest = WorkSchedule.restAt(
        anchor, anchor.add(const Duration(minutes: 55)), 50, 10)!;
    expect(rest.start, anchor.add(const Duration(minutes: 50)));
    expect(rest.end, anchor.add(const Duration(minutes: 60)));
    expect(
        WorkSchedule.restAt(
            anchor, anchor.add(const Duration(minutes: 60)), 50, 10),
        isNull);
    expect(
        WorkSchedule.restAt(
                anchor, anchor.add(const Duration(minutes: 115)), 50, 10)!
            .end,
        anchor.add(const Duration(minutes: 120)));
  });
  test('invalid start times do not become an invented schedule', () {
    expect(WorkSchedule.timeOnDay('25:00', DateTime(2026)), isNull);
    expect(WorkSchedule.timeOnDay(null, DateTime(2026)), isNull);
  });
}
