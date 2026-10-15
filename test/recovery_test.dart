import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/services/api_service.dart';
import 'package:suho_angel/utils/password_utils.dart';

void main() {
  test('disabled API makes no login request', () async {
    var calls = 0;
    final api = ApiService(
      enabled: false,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.login('test-user', 'test-password'),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
    api.close();
  });
  test('unknown password encoding fails rather than sending plaintext', () {
    expect(() => encodePassword('test-password', ''), throwsStateError);
  });
  test('missing work data is rejected rather than invented', () {
    expect(() => WorkInfo.fromJson({}), throwsFormatException);
  });
}
