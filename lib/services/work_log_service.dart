import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkLogService {
  final FlutterSecureStorage storage;
  WorkLogService({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  // Storage is namespaced by user to prevent showing another user's history.
  Future<List<Map<String, dynamic>>> load(int userId) async {
    final raw = await storage.read(key: 'recovery_work_logs_$userId');
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List) {
      throw const FormatException('Invalid local work history');
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> save(int userId, Map<String, dynamic> record) async {
    final list = await load(userId);
    list.removeWhere((r) => r['record_id'] == record['record_id']);
    list.insert(0, record);
    await storage.write(
        key: 'recovery_work_logs_$userId',
        value: jsonEncode(list.take(100).toList()));
  }
}
