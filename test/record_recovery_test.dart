import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/services/result_submission_service.dart';
import 'api_contract_test.dart' show MemorySession;
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/device_history_service.dart';
import 'package:suho_angel/services/work_log_service.dart';
import 'storage_submission_test.dart' show MemoryStore;
import 'device_history_test.dart' show reading;

class BackupFailureStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async {
    if (key.contains('_recovery_')) throw StateError('disk full');
    await super.write(key, value);
  }
}

class FailedSession extends MemorySession {
  @override
  Future<void> saveUserId(int value) async =>
      throw StateError('storage blocked');
}

void main() {
  test(
      'damaged receipt isolates one record, preserves evidence and blocks resend',
      () async {
    final store = MemoryStore();
    final broken = <String, dynamic>{
      'record_id': 'broken',
      'server_submitted': false,
      'request': {'packetid': 'broken', 'user_id': 31, 'process_version_id': 1},
    };
    store.data['recovery_work_logs_31'] = jsonEncode([
      broken,
      {'record_id': 'other', 'server_submitted': false},
    ]);
    store.data['recovery_receipt_31_broken'] = '{damaged';
    final logs = WorkLogService(store: store);
    final rows = await logs.load(31);
    expect(rows.length, 2);
    expect(rows.first['receipt_unverified'], isTrue);
    expect(rows.last.containsKey('receipt_unverified'), isFalse);
    await logs.save(31, {'record_id': 'new', 'server_submitted': false});
    expect((await logs.load(31)).length, 3);
    expect(store.data['recovery_receipt_31_broken'], '{damaged');
    var requests = 0;
    final session = MemorySession()
      ..id = 31
      ..token = 'fixture';
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"ret":1}', 200);
        }));
    addTearDown(api.close);
    final sender = ResultSubmissionService(api, logs);
    await expectLater(sender.send(31, broken), throwsA(isA<ApiFailure>()));
    expect(requests, 0);
    store.data['recovery_receipt_31_broken'] = '{"result_id":"77"}';
    final repaired =
        (await logs.load(31)).firstWhere((r) => r['record_id'] == 'broken');
    expect(repaired['server_submitted'], isTrue);
    expect(repaired.containsKey('receipt_unverified'), isFalse);
    expect((await sender.send(31, broken)).resultId, 77);
    expect(requests, 0);
  });
  test('malformed receipt objects never count as confirmation', () async {
    final store = MemoryStore();
    store.data['recovery_receipt_42_unknown'] = '{}';
    await expectLater(WorkLogService(store: store).receipt(42, 'unknown'),
        throwsA(isA<ReceiptReadFailure>()));
  });

  test('login storage failure is explicit and never leaves a partial session',
      () async {
    final session = FailedSession();
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async => http.Response(
            jsonEncode({'ret': 1, 'user_id': 31, 'access_token': 'fixture'}),
            200)));
    addTearDown(api.close);
    await expectLater(
        api.login('fixture', 'fake'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'storage guidance',
            contains('로그인 정보를 저장하지 못했습니다'))));
    expect(session.id, isNull);
    expect(session.token, isNull);
  });

  test('one malformed work row cannot block other history or new saves',
      () async {
    final store = MemoryStore();
    final raw = jsonEncode([
      {'record_id': 'pending', 'server_submitted': false},
      7
    ]);
    store.data['recovery_work_logs_31'] = raw;
    store.data['recovery_work_logs_42'] = '[]';
    final logs = WorkLogService(store: store);
    expect((await logs.load(31)).single['record_id'], 'pending');
    expect(logs.historyRecovered, isTrue);
    expect(
        store.data.entries
            .where((e) => e.key.startsWith('recovery_work_logs_31_recovery_'))
            .single
            .value,
        raw);
    await logs.save(31, {'record_id': 'new', 'server_submitted': false});
    expect((await logs.load(31)).length, 2);
    expect(store.data['recovery_work_logs_42'], '[]');
  });
  test('device history accepts old numeric strings and backs up invalid rows',
      () async {
    final store = MemoryStore(), now = DateTime.now();
    final history = DeviceHistoryService(store: store);
    final valid = reading(now).toJson()..['user_id'] = '31';
    valid['current'] = '250';
    valid['capacity'] = '1000';
    final key = history.key(31, 'partner', 'pet');
    store.data[key] = jsonEncode([
      valid,
      {'at': 'bad'},
      reading(now, user: 42).toJson()
    ]);
    final rows = await history.load(31, 'partner', 'pet');
    expect(rows.single.percent, 25);
    expect(history.historyRecovered, isTrue);
    await history.save(reading(now.add(const Duration(minutes: 10))));
    expect((await history.load(31, 'partner', 'pet')).length, 2);
    expect(await history.load(42, 'partner', 'pet'), isEmpty);
  });
  test('backup failure blocks replacement and preserves the damaged source',
      () async {
    final store = BackupFailureStore();
    final raw = jsonEncode([
      {'record_id': 'pending'},
      null
    ]);
    store.data['recovery_work_logs_31'] = raw;
    await expectLater(
        WorkLogService(store: store).save(31, {'record_id': 'new'}),
        throwsStateError);
    expect(store.data['recovery_work_logs_31'], raw);
  });
  test('unparseable histories fail visibly instead of being overwritten',
      () async {
    final store = MemoryStore();
    store.data['recovery_work_logs_31'] = '[broken';
    await expectLater(
        WorkLogService(store: store).save(31, {'record_id': 'new'}),
        throwsFormatException);
    expect(store.data['recovery_work_logs_31'], '[broken');
  });
}
