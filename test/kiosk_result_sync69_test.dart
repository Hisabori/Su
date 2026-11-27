import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/services/device_history_service.dart';
import 'package:suho_angel/services/kiosk_result_sync.dart';
import 'package:suho_angel/services/kiosk_sync_scope.dart';
import 'api_contract_test.dart' show MemorySession;
import 'storage_submission_test.dart' show MemoryStore;

DeviceReading reading({int user = 69}) => DeviceReading(
    userId: user,
    partner: 'greenhug',
    kiosk: 'VixVL4sPtmkwPaGHBWoR',
    name: '여주아울렛06',
    at: DateTime(2026, 11, 27, 13),
    current: 14,
    capacity: 1000,
    available: true);
Map<String, dynamic> row() => {
      'result_id': 1950,
      'user_id': 69,
      'work_id': 2,
      'process_version_id': 25,
      'work_date': '2026-11-27',
      'work_minutes': 5,
      'rest_minutes': 0,
      'actual_start_time': '10:24:29',
      'actual_end_time': '10:29:12',
      'result_json': jsonEncode([
        {'stepid': 74, '비고': 1}
      ])
    };

void main() {
  test('all six accounts synchronize only their own assigned result and keys',
      () async {
    final store = MemoryStore();
    for (final user in KioskSyncScope.kiosks.keys) {
      final sample = DeviceReading(
          userId: user,
          partner: 'greenhug',
          kiosk: KioskSyncScope.kiosks[user]!,
          name: '배정 기기',
          at: DateTime(2026, 11, 27, 13),
          current: 14,
          capacity: 1000,
          available: true);
      var rows = [
        {...row(), 'user_id': user}
      ];
      var deletes = 0, creates = 0;
      final api = ApiService(
          tokens: MemorySession()
            ..id = user
            ..token = 'mock',
          client: MockClient((request) async {
            final body =
                Map<String, dynamic>.from(jsonDecode(request.body) as Map);
            expect(body['user_id'], user);
            if (request.url.path.endsWith('list_work_result')) {
              return http.Response(jsonEncode({'ret': 1, 'results': rows}), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }
            expect(await store.read(KioskResultSync.pendingKeyFor(user)),
                isNotNull);
            if (request.url.path.endsWith('delete_work_result_manual')) {
              deletes++;
              rows = [];
              return http.Response('{"ret":1}', 200);
            }
            creates++;
            rows = [
              {
                ...body,
                'result_id': 2000 + user,
                'actual_start_time': body['start_time'],
                'actual_end_time': body['end_time']
              }
            ];
            return http.Response(
                jsonEncode({'ret': 1, 'result_id': 2000 + user}), 200);
          }));
      expect(
          await KioskResultSync(api, store: store)
              .sync(sample, workActive: false),
          '1.4% 관리자 기록 저장·대조 완료');
      expect(deletes, 1);
      expect(creates, 1);
      expect(await store.read(KioskResultSync.pendingKeyFor(user)), isNull);
      expect(await store.read(KioskResultSync.backupKeyFor(user)), isNotNull);
      final mismatch = ApiService(
          tokens: MemorySession()..id = 31,
          client:
              MockClient((_) async => fail('wrong session must not call API')));
      expect(
          await KioskResultSync(mismatch, store: store)
              .sync(sample, workActive: false),
          isNull);
    }
    expect(KioskSyncScope.kiosks.keys.toSet(), {69, 58, 64, 44, 81, 41});
    expect(
        KioskSyncScope.kiosks.keys
            .map(KioskResultSync.pendingKeyFor)
            .toSet()
            .length,
        6);
    expect(KioskResultSync.pendingKeyFor(69), 'kiosk_result_sync69_pending_v1');
  });
  test('allowed user cannot query or delete another allowed user result',
      () async {
    final api = ApiService(
        tokens: MemorySession()..id = 58,
        client: MockClient((_) async => fail('cross user API request')));
    expect(() => api.ownKioskResults('2026-11-27', userId: 64),
        throwsA(isA<ApiFailure>()));
    expect(() => api.deleteOwnKioskDay('2026-11-27', userId: 64),
        throwsA(isA<ApiFailure>()));
    for (final user in KioskSyncScope.kiosks.keys) {
      expect(KioskSyncScope.matches(user, 'greenhug', 'wrong-device'), isFalse);
      expect(
          KioskSyncScope.matches(user, 'other', KioskSyncScope.kiosks[user]!),
          isFalse);
    }
  });
  for (final count in [0, 2]) {
    test('$count existing results never triggers deletion', () async {
      final api = ApiService(
          tokens: MemorySession()
            ..id = 69
            ..token = 'mock',
          client: MockClient((request) async {
            expect(request.url.path, '/api/admin/list_work_result');
            return http.Response(
                jsonEncode(
                    {'ret': 1, 'results': List.generate(count, (_) => row())}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }));
      final store = MemoryStore();
      await KioskResultSync(api, store: store)
          .sync(reading(), workActive: false);
      expect(await store.read(KioskResultSync.key), isNull);
    });
  }
  test('concurrent server edit cancels before destructive request', () async {
    var reads = 0;
    final api = ApiService(
        tokens: MemorySession()
          ..id = 69
          ..token = 'mock',
        client: MockClient((request) async {
          expect(request.url.path, '/api/admin/list_work_result');
          reads++;
          return http.Response(
              jsonEncode({
                'ret': 1,
                'results': [
                  {...row(), if (reads > 1) 'work_minutes': 99}
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final store = MemoryStore();
    expect(
        await KioskResultSync(api, store: store)
            .sync(reading(), workActive: false),
        contains('변경돼'));
    expect(reads, 2);
    expect(await store.read(KioskResultSync.key), isNull);
  });
  test('preserves answers/times, merges point and rejects scope changes', () {
    final body = KioskResultSync.candidate(row(), reading());
    expect(body['start_time'], '2026-11-27 10:24:29');
    expect(() => KioskResultSync.candidate({...row(), 'work_id': 3}, reading()),
        throwsA(isA<ApiFailure>()));
    final items = jsonDecode(body['result_json'] as String) as List;
    expect(items.first, {'stepid': 74, '비고': 1});
    expect(items.last['기기상태체크'], '1.4%');
    expect(() => KioskResultSync.candidate(row(), reading(user: 31)),
        throwsA(isA<ApiFailure>()));
    expect(
        () => KioskResultSync.candidate(
            {...row(), 'work_date': '2026-11-26'}, reading()),
        throwsA(isA<ApiFailure>()));
    final replay = KioskResultSync.candidate(
        {...row(), 'result_json': body['result_json']}, reading());
    expect(replay['result_json'], body['result_json']);
  });

  test(
      'authenticated mock delete/create/readback, storage backup before delete',
      () async {
    final store = MemoryStore();
    var rows = [row()];
    var deletes = 0, creates = 0;
    final api = ApiService(
        tokens: MemorySession()
          ..id = 69
          ..token = 'mock',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(request.headers['Authorization'], 'Bearer mock');
          expect(body['user_id'], 69);
          if (request.url.path.endsWith('list_work_result')) {
            return http.Response(jsonEncode({'ret': 1, 'results': rows}), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          expect(await store.read(KioskResultSync.key), isNotNull);
          if (request.url.path.endsWith('delete_work_result_manual')) {
            deletes++;
            rows = [];
            return http.Response('{"ret":1}', 200);
          }
          creates++;
          rows = [
            {
              ...body.cast<String, dynamic>(),
              'result_id': 2000,
              'actual_start_time': body['start_time'],
              'actual_end_time': body['end_time']
            }
          ];
          return http.Response('{"ret":1,"result_id":2000}', 200);
        }));
    final service = KioskResultSync(api, store: store);
    expect(await service.sync(reading(), workActive: false),
        equals('1.4% 관리자 기록 저장·대조 완료'));
    expect(deletes, 1);
    expect(creates, 1);
    expect(await store.read(KioskResultSync.key), isNull);
    expect(await store.read(KioskResultSync.backupKey), isNotNull);
    await service.sync(reading(), workActive: false);
    expect(deletes, 1);
    expect(creates, 1);
  });

  test('uncertain delete keeps backup and blocks replay', () async {
    var deletes = 0;
    final store = MemoryStore();
    final api = ApiService(
        tokens: MemorySession()
          ..id = 69
          ..token = 'mock',
        client: MockClient((request) async {
          if (request.url.path.endsWith('list_work_result')) {
            return http.Response(
                jsonEncode({
                  'ret': 1,
                  'results': [row()]
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          deletes++;
          throw http.ClientException('simulated disconnect');
        }));
    final service = KioskResultSync(api, store: store);
    await service.sync(reading(), workActive: false);
    await service.sync(reading(), workActive: false);
    expect(deletes, 1);
    expect(await store.read(KioskResultSync.key), isNotNull);
  });

  test('other user and active work never call administrator API', () async {
    final tokens = MemorySession()..id = 69;
    final api = ApiService(
        tokens: tokens,
        client: MockClient((_) async => fail('No network allowed')));
    final service = KioskResultSync(api, store: MemoryStore());
    expect(await service.sync(reading(user: 31), workActive: false), isNull);
    expect(await service.sync(reading(), workActive: true), contains('근무 완료'));
  });
}
