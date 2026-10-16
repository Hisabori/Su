import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/work_log_service.dart';
import 'storage_submission_test.dart' show MemoryStore;

void main() {
  test(
      'only a confirmed same-user same-assignment same-day result restores completion',
      () async {
    final logs = WorkLogService(store: MemoryStore());
    final now = DateTime(2026, 10, 16, 9);
    final record = <String, dynamic>{
      'record_id': 'receipt',
      'assignment_signature': 'assignment-a',
      'started_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'ended_at': now.toIso8601String(),
      'request': {'user_id': 42},
      'server_submitted': false,
    };
    await logs.save(42, record);
    expect(await logs.completedAssignment(42, 'assignment-a', now), isNull);
    await logs.confirm(42, record, 7);
    expect(
        (await logs.completedAssignment(42, 'assignment-a', now))?['result_id'],
        7);
    expect(await logs.completedAssignment(43, 'assignment-a', now), isNull);
    expect(await logs.completedAssignment(42, 'assignment-b', now), isNull);
    expect(
        await logs.completedAssignment(
            42, 'assignment-a', now.add(const Duration(days: 1))),
        isNull);
  });
}
