import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/services/access_service.dart';
import 'package:suho_angel/services/api_service.dart';
import 'api_contract_test.dart' show MemorySession;

class AccessSession extends MemorySession {
  @override
  Future<Map<String, dynamic>> device() async =>
      {'community_session': 'a' * 64};
}

void main() {
  test(
      'every client instance reports an access, with stable retry ID and no claimed identity',
      () async {
    final requests = <Map<String, dynamic>>[];
    final tokens = AccessSession()
      ..token = 'fixture'
      ..id = 42;
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      requests.add(body);
      expect(req.headers['Authorization'], 'Bearer fixture');
      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('name'), isFalse);
      return http.Response('{"access_recorded":true}', 200);
    });
    final first = AccessService(client: client, tokens: tokens),
        second = AccessService(client: client, tokens: tokens);
    await first.recordOpen();
    await first.recordOpen();
    await second.recordOpen();
    expect(requests.length, 3);
    expect(
        requests[0]['event_id'],
        matches(RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
    expect(requests[0]['event_id'], requests[1]['event_id']);
    expect(requests[0]['event_id'], isNot(requests[2]['event_id']));
    expect(requests[0].containsKey('at'), isFalse);
    client.close();
  });
  test('a rejected or unconfirmed access is not reported as saved', () async {
    for (final response in [
      http.Response('{"access_recorded":false,"error_code":"ACC-202"}', 200),
      http.Response('{"message":"unbound","error_code":"ACC-002"}', 409)
    ]) {
      final access = AccessService(
          tokens: AccessSession()..token = 'fixture',
          client: MockClient((_) async => response));
      await expectLater(access.recordOpen(), throwsA(isA<ApiFailure>()));
      access.close();
    }
  });
}
