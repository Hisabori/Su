import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/community_service.dart';
import 'package:suho_angel/services/device_cloud_service.dart';
import 'package:suho_angel/services/device_history_service.dart';
import 'api_contract_test.dart' show MemorySession;
import 'storage_submission_test.dart' show MemoryStore;
import 'device_history_test.dart' show reading, FullStore;

class CloudSession extends MemorySession {
  @override
  Future<Map<String, dynamic>> device() async => {
        'company_device_name': 'partner',
        'kiosk_id': 'pet',
        'device_history_enabled': true,
        'community_session': 'a' * 64,
      };
}

void main() {
  test('local observation is saved before a slow cloud request finishes',
      () async {
    final store = MemoryStore(),
        started = Completer<void>(),
        gate = Completer<bool>();
    final history = DeviceHistoryService(
        store: store,
        remoteSample: () {
          started.complete();
          return gate.future;
        });
    final saving = history.save(reading(DateTime.now()));
    await started.future;
    expect(
        (await DeviceHistoryService(store: store).load(31, 'partner', 'pet'))
            .length,
        1);
    gate.complete(true);
    await saving;
  });

  test('new clients read shared server values without uploading local values',
      () async {
    final rows = <Map<String, dynamic>>[];
    DeviceCloudService client(int user) {
      final tokens = CloudSession()
        ..id = user
        ..token = 'fixture';
      final service = CommunityService(
          tokens: tokens,
          client: MockClient((req) async {
            final body = jsonDecode(req.body) as Map;
            expect(req.headers['Authorization'], 'Bearer fixture');
            if (body['action'] == 'device_sample') {
              expect(body.keys, ['action']);
              final row = reading(DateTime.now()).toJson()..remove('user_id');
              rows.add(row);
              return http.Response(jsonEncode({'reading': row}), 200);
            }
            return http.Response(
                jsonEncode({'records': rows, 'cursor': null}), 200);
          }));
      final cloud = DeviceCloudService(service: service, tokens: tokens);
      addTearDown(cloud.close);
      return cloud;
    }

    final first = client(31), second = client(42);
    expect(await first.sample(), isTrue);
    final history = await second.load();
    expect(history!.single.userId, 42);
    expect(history.single.percent, 25);
    expect(second.hasMore, isFalse);
  });
  test('cloud history and saves survive unavailable local storage', () async {
    final row = reading(DateTime.now());
    final history = DeviceHistoryService(
        store: FullStore(),
        remoteLoad: () async => [row],
        remoteSample: () async => true);
    await history.save(row);
    expect(history.localStorageFailed, isTrue);
    expect(history.cloudConnected, isTrue);
    expect((await history.load(31, 'partner', 'pet')).single.percent, 25);
    expect(await history.load(42, 'partner', 'pet'), isEmpty);
  });
  test('cloud failures retain the local fallback without pretending to sync',
      () async {
    final store = MemoryStore();
    final local = DeviceHistoryService(store: store);
    await local.save(reading(DateTime.now()));
    final history = DeviceHistoryService(
        store: store,
        remoteLoad: () async => throw StateError('offline'),
        remoteSample: () async => throw StateError('offline'));
    expect((await history.load(31, 'partner', 'pet')).length, 1);
    expect(history.cloudConnected, isFalse);
    expect(history.cloudError, isNotNull);
    await history.save(reading(DateTime.now()));
    expect((await local.load(31, 'partner', 'pet')).length, 2);
  });
}
