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

  Future<void> clear() async {
    await storage.delete(key: 'jwt_access_token');
    await storage.delete(key: 'jwt_refresh_token');
  }
}
