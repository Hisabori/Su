import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/services/work_draft_service.dart';
import 'storage_submission_test.dart' show MemoryStore;

WorkInfo fixture({int version = 1}) => WorkInfo(
    id: '8',
    name: '업무',
    processVersionId: version,
    steps: [WorkStep(id: '2', name: '단계', prompt: '확인')]);
Map<String, dynamic> checkpoint(DateTime start) => {
      'index': 0,
      'question_index': 0,
      'started_at': start.toIso8601String(),
      'step_started_at': start.toIso8601String(),
      'schedule_anchor': start.toIso8601String(),
      'rest_seconds': 0,
      'step_rest_seconds': 0,
      'answers': <Map<String, dynamic>>[],
      'device_checks': [],
    };
void main() {
  final now = DateTime(2026, 10, 16, 12);
  test(
      'checkpoint survives reload, preserves snapshots, and isolates user and assignment',
      () async {
    final store = MemoryStore();
    final service = WorkDraftService(store: store);
    final state = checkpoint(now.subtract(const Duration(minutes: 2)));
    final save = service.save(42, fixture(), state);
    state['index'] = 99;
    await save;
    final restarted = WorkDraftService(store: store);
    expect((await restarted.load(42, fixture(), now: now))!['index'], 0);
    expect(await restarted.load(43, fixture(), now: now), isNull);
    expect(await restarted.load(42, fixture(version: 2), now: now), isNull);
  });
  test('corrupted and out-of-range checkpoints are ignored', () async {
    final store = MemoryStore();
    final service = WorkDraftService(store: store);
    store.data['recovery_work_draft_42'] = 'invalid';
    expect(await service.load(42, fixture(), now: now), isNull);
    await service.save(42, fixture(), {...checkpoint(now), 'index': 5});
    expect(await service.load(42, fixture(), now: now), isNull);
    final raw = jsonDecode(store.data['recovery_work_draft_42']!) as Map;
    raw['state']['index'] = 0;
    raw['state']['answers'] = ['invalid'];
    store.data['recovery_work_draft_42'] = jsonEncode(raw);
    expect(await service.load(42, fixture(), now: now), isNull);
  });
  test('expired progress is ignored but a pending result can be recovered',
      () async {
    final service = WorkDraftService(store: MemoryStore());
    final state = checkpoint(now.subtract(const Duration(hours: 5)));
    await service.save(42, fixture(), state);
    expect(await service.load(42, fixture(), now: now), isNull);
    state['pending_record'] = {
      'record_id': 'result_1',
      'request': {'packetid': 'result_1', 'user_id': 42}
    };
    await service.save(42, fixture(), state);
    expect(await service.load(42, fixture(), now: now), isNotNull);
    state['pending_record']['request']['user_id'] = 7;
    await service.save(42, fixture(), state);
    expect(await service.load(42, fixture(), now: now), isNull);
  });
  test('clear runs after queued saves so completed work cannot reappear',
      () async {
    final service = WorkDraftService(store: MemoryStore());
    await Future.wait(
        [service.save(42, fixture(), checkpoint(now)), service.clear(42)]);
    expect(await service.load(42, fixture(), now: now), isNull);
  });
}
