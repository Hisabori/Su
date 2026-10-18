import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/api_service.dart';
import 'api_contract_test.dart' show MemorySession;

void main() {
  test(
      'community login sends a hash and trusts numeric identity from server result',
      () async {
    final session = MemorySession();
    final api = ApiService(
        communityLogin: true,
        tokens: session,
        client: MockClient((request) async {
          expect(request.url.host, 'suho-angel.vercel.app');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map;
          expect(body['action'], 'login');
          expect(body['username'], 'cesco999');
          expect(body['password'], matches(RegExp(r'^[a-f0-9]{64}$')));
          expect(body.containsKey('name'), isFalse);
          return http.Response(
              jsonEncode({
                'ret': 1,
                'user_id': 31,
                'name': '정훈',
                'access_token': 'test-only',
                'community_session': 'a' * 64
              }),
              200);
        }));
    await api.login('cesco999', 'fake-password');
    expect(session.id, 31);
    expect(session.token, 'test-only');
    api.close();
  });
  test(
      'unavailable community falls back to work login but denial never triggers retry',
      () async {
    for (final status in [503, 200]) {
      var calls = 0;
      final session = MemorySession();
      final api = ApiService(
          communityLogin: true,
          tokens: session,
          client: MockClient((request) async {
            calls++;
            if (request.method == 'POST') {
              return http.Response(jsonEncode({'ret': 4}), status);
            }
            return http.Response(
                jsonEncode(
                    {'ret': 1, 'user_id': 31, 'access_token': 'test-only'}),
                200);
          }));
      if (status == 503) {
        await api.login('demo', 'fake');
        expect(calls, 2);
        expect(session.id, 31);
      } else {
        await expectLater(api.login('demo', 'fake'),
            throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 4)));
        expect(calls, 1);
        expect(session.id, isNull);
      }
      api.close();
    }
  });
}
