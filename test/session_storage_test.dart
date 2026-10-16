import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/token_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = <String, String>{};
  setUp(() {
    data.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return data[key];
        case 'write':
          data[key] = args['value'] as String;
          return null;
        case 'delete':
          data.remove(key);
          return null;
        default:
          throw StateError('Unexpected storage action: ${call.method}');
      }
    });
  });
  test(
      'session export and import preserve the user and device without unrelated records',
      () async {
    final tokens = TokenStorageService();
    data['recovery_work_logs_42'] = 'keep-records';
    await tokens.saveUserId(42);
    await tokens.save('fake-access', 'fake-refresh');
    await tokens.saveDevice(
        {'company_device_name': 'partner', 'kiosk_id': 7, 'name': '테스트 사용자'});
    final snapshot = await tokens.snapshot();
    expect(snapshot.containsKey('recovery_work_logs_42'), isFalse);
    await tokens.clearPersisted();
    expect(await tokens.read(), isNull);
    expect(data['recovery_work_logs_42'], 'keep-records');
    await tokens.restoreSnapshot(snapshot);
    expect(await tokens.userId(), 42);
    expect(await tokens.read(), 'fake-access');
    expect((await tokens.device())['kiosk_id'], 7);
    expect((await tokens.device())['name'], '테스트 사용자');
    expect(data['jwt_refresh_token'], 'fake-refresh');
  });
  test('invalid session import cannot erase a valid login or work records',
      () async {
    final tokens = TokenStorageService();
    await tokens.saveUserId(42);
    await tokens.save('existing-fake', null);
    await expectLater(tokens.restoreSnapshot({'jwt_access_token': 'other'}),
        throwsFormatException);
    expect(await tokens.read(), 'existing-fake');
    expect(await tokens.userId(), 42);
  });
}
