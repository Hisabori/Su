import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/services/token_storage_service.dart';

class MemorySession extends TokenStorageService {
  @override
  Future<void> clear() async {
    token = null;
    id = null;
  }

  String? token;
  @override
  Future<void> saveDevice(Map<String, dynamic> login) async {}
  int? id;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String value, String? refresh) async {
    token = value;
  }

  @override
  Future<void> saveUserId(int value) async {
    id = value;
  }

  @override
  Future<int?> userId() async => id;
}

void main() {
  test(
      'original login rejection codes retain their meaning and never create a session',
      () async {
    for (final entry
        in {2: '비밀번호', 3: '존재하지', 4: '권한', 5: '비활성화', 6: '주말'}.entries) {
      final session = MemorySession();
      final api = ApiService(
          tokens: session,
          client: MockClient(
              (_) async => http.Response(jsonEncode({'ret': entry.key}), 200)));
      await expectLater(
          api.login('test', 'fake'),
          throwsA(isA<ApiFailure>()
              .having((e) => e.code, 'code', entry.key)
              .having((e) => e.message, 'message', contains(entry.value))));
      expect(session.token, isNull);
      expect(session.id, isNull);
      api.close();
    }
  });

  test(
      'login uses PUT with a hash and work lookup sends the authenticated user id',
      () async {
    final session = MemorySession();
    final api = ApiService(
        tokens: session,
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/login')) {
            expect(body['username'], 'test-user');
            expect(body['packetid'], startsWith('login_'));
            expect(body['password'],
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4');
            return http.Response(
                jsonEncode(
                    {'ret': 1, 'access_token': 'test-token', 'user_id': 42}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(body['user_id'], 42);
          expect(body['packetid'], startsWith('work_info_'));
          return http.Response(
              jsonEncode({
                'ret': 1,
                'work': {'work_id': 9, 'work_name': '작업'},
                'steps': [
                  {
                    'step_id': 1,
                    'step_name': '확인',
                    'start_ment': '준비됐나요?',
                    'question': ['질문 1', '질문 2']
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await api.login('test-user', '1234');
    final work = await api.getWorkInfo();
    expect(work.steps.single.questions.length, 2);
    api.close();
  });
  test('HTTP 200 with a business rejection never creates a session', () async {
    final session = MemorySession();
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async => http.Response(
            jsonEncode({'ret': 6, 'access_token': 'unexpected', 'user_id': 42}),
            200)));
    await expectLater(api.login('test', '1234'), throwsA(isA<ApiFailure>()));
    expect(session.token, isNull);
    expect(session.id, isNull);
    api.close();
  });
  test('result submission preserves packet id and only ret 1 counts as saved',
      () async {
    final session = MemorySession()
      ..token = 'test-token'
      ..id = 42;
    var calls = 0;
    final request = {
      'packetid': 'work_result_fixed',
      'user_id': 42,
      'process_version_id': 12,
      'result_json': '[]'
    };
    final api = ApiService(
        tokens: session,
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/user/work_result');
          expect(jsonDecode(r.body)['packetid'], 'work_result_fixed');
          return http.Response(
              jsonEncode({'ret': calls == 1 ? 0 : 1, 'result_id': 77}), 200);
        }));
    await expectLater(
        api.submitWorkResult(request), throwsA(isA<ApiFailure>()));
    expect(calls, 1);
    expect(await api.submitWorkResult(request), 77);
    api.close();
  });
  test('result from another user is never sent', () async {
    final session = MemorySession()
      ..token = 'test-token'
      ..id = 42;
    var calls = 0;
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }));
    await expectLater(
        api.submitWorkResult({'user_id': 43, 'process_version_id': 12}),
        throwsA(isA<ApiFailure>()));
    expect(calls, 0);
    api.close();
  });
}
