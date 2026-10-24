import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/services/app_preferences.dart';
import 'package:suho_angel/services/session_restore_service.dart';
import 'api_contract_test.dart' show MemorySession;
import 'storage_submission_test.dart' show MemoryStore;

void main() {
  test('disabled, absent and locked sessions never call the server', () async {
    final preferences = AppPreferences(store: MemoryStore());
    final session = MemorySession()
      ..token = 'fixture'
      ..id = 31;
    var calls = 0;
    final api = ApiService(
        tokens: session,
        client: MockClient((_) async {
          calls++;
          return http.Response('{"ret":1}', 200);
        }));
    addTearDown(api.close);
    final restore = SessionRestoreService(api: api, preferences: preferences);
    await preferences.setAutoLoginEnabled(false);
    expect(await restore.restore(), SessionRestoreResult.disabled);
    expect(session.token, 'fixture');
    await preferences.setAutoLoginEnabled(true);
    session.token = null;
    expect(await restore.restore(), SessionRestoreResult.missing);
    expect(calls, 0);
  });
  test(
      'valid saved sessions use authenticated token verification, never password login',
      () async {
    final session = MemorySession()
      ..token = 'fixture'
      ..id = 31;
    final api = ApiService(
        tokens: session,
        client: MockClient((r) async {
          expect(r.url.path, '/api/user/validate_token');
          expect(r.headers['Authorization'], 'Bearer fixture');
          final body = jsonDecode(r.body) as Map;
          expect(body['token'], 'fixture');
          expect(body.containsKey('password'), false);
          return http.Response('{"ret":1}', 200);
        }));
    addTearDown(api.close);
    expect(
        await SessionRestoreService(
                api: api, preferences: AppPreferences(store: MemoryStore()))
            .restore(),
        SessionRestoreResult.restored);
  });
  test(
      'explicit token rejection clears credentials, transient failures retain them',
      () async {
    for (final response in [
      http.Response('{"ret":0}', 200),
      http.Response('{}', 401),
      http.Response('{}', 403),
      http.Response('{}', 503)
    ]) {
      final session = MemorySession()
        ..token = 'fixture'
        ..id = 31;
      final api = ApiService(
          tokens: session, client: MockClient((_) async => response));
      final restore = SessionRestoreService(
          api: api, preferences: AppPreferences(store: MemoryStore()));
      if (response.statusCode == 503) {
        await expectLater(restore.restore(), throwsA(isA<ApiFailure>()));
        expect(session.token, 'fixture');
      } else {
        expect(await restore.restore(), SessionRestoreResult.expired);
        expect(session.token, isNull);
        expect(session.id, isNull);
      }
      api.close();
    }
  });
}
