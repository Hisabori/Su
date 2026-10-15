import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'passkey_platform.dart' as passkeys;

class TokenStorageService {
  final FlutterSecureStorage storage;
  TokenStorageService({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  static const sessionKeys = [
    'auth_device',
    'auth_user_id',
    'jwt_access_token',
    'jwt_refresh_token'
  ];
  Future<String?> _read(String key) async => passkeys.passkeyEnrolled
      ? passkeys.passkeyRead(key)
      : storage.read(key: key);
  Future<void> _write(String key, String value) async {
    if (passkeys.passkeyEnrolled) {
      passkeys.passkeyWrite(key, value);
    } else {
      await storage.write(key: key, value: value);
    }
  }

  Future<void> _delete(String key) async {
    if (passkeys.passkeyEnrolled) {
      passkeys.passkeyRemove(key);
    } else {
      await storage.delete(key: key);
    }
  }

  Future<Map<String, String?>> snapshot() async => {
        for (final key in sessionKeys) key: await _read(key),
      };
  Future<void> restoreSnapshot(Map<String, String?> data) async {
    final token = data['jwt_access_token'];
    final user = int.tryParse(data['auth_user_id'] ?? '');
    if (token == null || token.isEmpty || user == null || user <= 0) {
      throw const FormatException('Invalid session');
    }
    await clear();
    try {
      for (final key in sessionKeys) {
        final value = data[key];
        if (value != null) await _write(key, value);
      }
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  // Erase the legacy token copy after successful PRF vault creation.
  Future<void> clearPersisted() async {
    for (final key in sessionKeys) {
      await storage.delete(key: key);
      if (await storage.read(key: key) != null) {
        throw StateError('Session cleanup failed');
      }
    }
  }

  Future<String?> read() => _read('jwt_access_token');
  Future<void> save(String token, String? refresh) async {
    await _write('jwt_access_token', token);
    if (refresh != null) {
      await _write('jwt_refresh_token', refresh);
    } else {
      await _delete('jwt_refresh_token');
    }
  }

  Future<void> saveUserId(int userId) => _write('auth_user_id', '$userId');
  Future<int?> userId() async =>
      int.tryParse(await _read('auth_user_id') ?? '');
  Future<void> saveDevice(Map<String, dynamic> login) => _write(
      'auth_device',
      jsonEncode({
        'company_device_name': login['company_device_name'],
        'kiosk_id': login['kiosk_id']
      }));
  Future<Map<String, dynamic>> device() async {
    final raw = await _read('auth_device');
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> clear() async {
    for (final key in sessionKeys) {
      await _delete(key);
    }
  }
}
