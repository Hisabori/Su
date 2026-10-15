import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  final FlutterSecureStorage storage;
  TokenStorageService({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  Future<String?> read() => storage.read(key: 'jwt_access_token');
  Future<void> save(String token, String? refresh) async {
    await storage.write(key: 'jwt_access_token', value: token);
    if (refresh != null) {
      await storage.write(key: 'jwt_refresh_token', value: refresh);
    } else {
      await storage.delete(key: 'jwt_refresh_token');
    }
  }

  Future<void> saveUserId(int userId) =>
      storage.write(key: 'auth_user_id', value: '$userId');
  Future<int?> userId() async =>
      int.tryParse(await storage.read(key: 'auth_user_id') ?? '');
  Future<void> saveDevice(Map<String, dynamic> login) => storage.write(
      key: 'auth_device',
      value: jsonEncode({
        'company_device_name': login['company_device_name'],
        'kiosk_id': login['kiosk_id']
      }));
  Future<Map<String, dynamic>> device() async {
    final raw = await storage.read(key: 'auth_device');
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> clear() async {
    await storage.delete(key: 'auth_device');
    await storage.delete(key: 'auth_user_id');
    await storage.delete(key: 'jwt_access_token');
    await storage.delete(key: 'jwt_refresh_token');
  }
}
