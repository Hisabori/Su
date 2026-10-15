import 'dart:convert';
import 'local_store.dart';

class SavedReceipt {
  final int? resultId;
  const SavedReceipt(this.resultId);
}

class WorkLogService {
  static final LocalStore _defaultStore = SecureLocalStore();
  static Future<void> _writes = Future<void>.value();
  static final Map<String, SavedReceipt> _receipts = {};
  final LocalStore store;
  WorkLogService({LocalStore? store}) : store = store ?? _defaultStore;
  String get scope => '${identityHashCode(store)}';
  String _cacheKey(int user, String record) => '$scope/$user/$record';
  String _receiptKey(int user, String record) =>
      'recovery_receipt_${user}_$record';

  Future<T> _write<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<Map<String, dynamic>>> _read(int userId) async {
    final raw = await store.read('recovery_work_logs_$userId');
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List || data.any((r) => r is! Map<String, dynamic>)) {
      throw const FormatException('Invalid local work history');
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<SavedReceipt?> receipt(int userId, String recordId) async {
    final key = _cacheKey(userId, recordId);
    if (_receipts.containsKey(key)) return _receipts[key];
    final raw = await store.read(_receiptKey(userId, recordId));
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final receipt = SavedReceipt(data['result_id'] as int?);
      _receipts[key] = receipt;
      return receipt;
    }
    // A history update may have succeeded even if writing the receipt failed.
    for (final record in await _read(userId)) {
      if (record['record_id'] == recordId &&
          record['server_submitted'] == true) {
        final receipt = SavedReceipt(record['result_id'] as int?);
        _receipts[key] = receipt;
        return receipt;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> load(int userId) async {
    final records = await _read(userId);
    for (final record in records) {
      final id = record['record_id'];
      if (record['server_submitted'] != true && id is String) {
        final confirmed = await receipt(userId, id);
        if (confirmed != null) {
          record['server_submitted'] = true;
          record['result_id'] = confirmed.resultId;
        }
      }
    }
    return records;
  }

  Future<void> save(int userId, Map<String, dynamic> record) {
    final snapshot = jsonDecode(jsonEncode(record)) as Map<String, dynamic>;
    return _write(() async {
      final list = await load(userId);
      final id = snapshot['record_id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Missing record id');
      }
      final prior = list.where((r) => r['record_id'] == id);
      if (prior.any((r) => r['server_submitted'] == true)) {
        snapshot['server_submitted'] = true;
        snapshot['result_id'] = prior.first['result_id'];
      }
      list.removeWhere((r) => r['record_id'] == id);
      list.insert(0, snapshot);
      var savedCount = 0;
      // Pending results must survive even when the history exceeds 100 entries.
      final retained = list
          .where((r) => r['server_submitted'] != true || ++savedCount <= 100)
          .toList();
      await store.write('recovery_work_logs_$userId', jsonEncode(retained));
    });
  }

  Future<bool> confirm(
      int userId, Map<String, dynamic> record, int? resultId) async {
    final id = record['record_id'] as String;
    _receipts[_cacheKey(userId, id)] = SavedReceipt(resultId);
    var persisted = false;
    try {
      await store.write(
          _receiptKey(userId, id), jsonEncode({'result_id': resultId}));
      persisted = true;
    } catch (_) {/* The independent history write is still worth attempting. */}
    try {
      await save(
          userId, {...record, 'server_submitted': true, 'result_id': resultId});
      persisted = true;
    } catch (_) {/* A server acknowledgement must not become a resend. */}
    return persisted;
  }
}
