import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/services/local_store.dart';
import 'package:suho_angel/services/result_submission_service.dart';
import 'package:suho_angel/services/work_log_service.dart';
import 'api_contract_test.dart' show MemorySession;

class MemoryStore implements LocalStore {
  final Map<String, String> data;
  bool failHistory = false;
  MemoryStore([Map<String, String>? data]) : data = data ?? {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    if (failHistory && key.startsWith('recovery_work_logs_')) {
      throw StateError('disk full');
    }
    data[key] = value;
  }
}

Map<String, dynamic> record(String id) => {
      'record_id': id,
      'server_submitted': false,
      'request': {'packetid': id, 'user_id': 42, 'process_version_id': 1},
    };
void main() {
  test(
      'concurrent history writes preserve every pending record and isolate users',
      () async {
    final logs = WorkLogService(store: MemoryStore());
    await Future.wait(List.generate(105, (i) => logs.save(42, record('r$i'))));
    expect((await logs.load(42)).length, 105);
    expect(await logs.load(7), isEmpty);
    await logs.save(7, record('other'));
    expect((await logs.load(42)).length, 105);
  });
  test(
      'simultaneous sends share one request and acknowledge despite history failure',
      () async {
    final store = MemoryStore();
    final logs = WorkLogService(store: store);
    final session = MemorySession()
      ..id = 42
      ..token = 'fake';
    var requests = 0;
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async {
          requests++;
          store.failHistory = true;
          return http.Response(jsonEncode({'ret': 1, 'result_id': 90}), 200);
        }));
    final sender = ResultSubmissionService(api, logs);
    final outcomes = await Future.wait(
        [sender.send(42, record('one')), sender.send(42, record('one'))]);
    expect(requests, 1);
    expect(
        outcomes.every((r) => r.resultId == 90 && r.persistedLocally), isTrue);
    // New store identity simulates losing the in-memory acknowledgement on restart.
    final restarted = WorkLogService(store: MemoryStore(store.data));
    expect((await restarted.load(42)).single['server_submitted'], isTrue);
    await ResultSubmissionService(api, restarted).send(42, record('one'));
    expect(requests, 1);
    api.close();
  });
  test('a confirmed record cannot be downgraded by a stale save', () async {
    final logs = WorkLogService(store: MemoryStore());
    await logs.save(42, record('one'));
    await logs.confirm(42, record('one'), 9);
    await logs.save(42, record('one'));
    expect((await logs.load(42)).single['result_id'], 9);
    expect((await logs.load(42)).single['server_submitted'], isTrue);
  });
  test('original prompt fallback skips whitespace and empty announcements', () {
    expect(
        WorkStep.fromJson({
          'step_id': 1,
          'step_name': '단계',
          'start_ment': ' ',
          'description': ' 설명 '
        }).prompt,
        '설명');
    expect(
        WorkStep.fromJson({'step_id': 1, 'step_name': '', 'work_seconds': -1})
            .prompt,
        '단계를 확인해 주세요.');
    expect(
        WorkStep.fromJson({'step_id': 1, 'step_name': '', 'work_seconds': -1})
            .workSeconds,
        0);
  });
}
