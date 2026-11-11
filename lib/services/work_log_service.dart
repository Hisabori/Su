import 'dart:convert';
import 'local_store.dart';
import 'record_recovery.dart';
import 'diagnostic_log.dart';

class ReceiptReadFailure implements Exception {
  const ReceiptReadFailure();
}

class SavedReceipt {
  final int? resultId;
  const SavedReceipt(this.resultId);
}

class WorkLogService {
  static final LocalStore _defaultStore = SecureLocalStore();
  static Future<void> _writes = Future<void>.value();
  static final Map<String, SavedReceipt> _receipts = {};
  final LocalStore store;
  bool historyRecovered = false;
  WorkLogService({LocalStore? store}) : store = store ?? _defaultStore;
  String get scope => '${identityHashCode(store)}';
  String _cacheKey(int user, String record) => '$scope/$user/$record';
  String _receiptKey(int user, String record) =>
      'recovery_receipt_${user}_$record';

  Future<T> _write<T>(Future<T> Function() operation) {
    final result = _writes
        .then((_) => operation())
        .catchError((Object error, StackTrace stack) {
      DiagnosticLog.record('work_history', 'save_failed');
      Error.throwWithStackTrace(error, stack);
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<Map<String, dynamic>>> _read(int userId) async {
    final recovered = await readRecoverableRecords<Map<String, dynamic>>(
        store, 'recovery_work_logs_$userId', (row) => row);
    historyRecovered = recovered.recovered;
    return recovered.records;
  }

  Future<SavedReceipt?> receipt(int userId, String recordId) async {
    try {
      return await _receipt(userId, recordId);
    } catch (_) {
      DiagnosticLog.record('work_history', 'read_failed');
      throw const ReceiptReadFailure();
    }
  }

  int? receiptId(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final id = int.tryParse(value);
      if (id != null) return id;
    }
    throw const FormatException('Invalid receipt result ID');
  }

  Future<SavedReceipt?> _receipt(int userId, String recordId) async {
    final key = _cacheKey(userId, recordId);
    if (_receipts.containsKey(key)) return _receipts[key];
    final raw = await store.read(_receiptKey(userId, recordId));
    if (raw != null) {
      final data = jsonDecode(raw);
      if (data is! Map || !data.containsKey('result_id')) {
        throw const FormatException('Invalid receipt');
      }
      final receipt = SavedReceipt(receiptId(data['result_id']));
      _receipts[key] = receipt;
      return receipt;
    }
    // A history update may have succeeded even if writing the receipt failed.
    for (final record in await _read(userId)) {
      if (record['record_id'] == recordId &&
          record['server_submitted'] == true) {
        final receipt = SavedReceipt(receiptId(record['result_id']));
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
      record.remove('receipt_unverified');
      if (record['server_submitted'] != true && id is String) {
        try {
          final confirmed = await receipt(userId, id);
          if (confirmed != null) {
            record['server_submitted'] = true;
            record['result_id'] = confirmed.resultId;
          }
        } on ReceiptReadFailure {
          record['receipt_unverified'] = true;
        }
      }
    }
    return records;
  }

  /// Only a confirmed receipt for this user, assignment and day is completion.
  Future<Map<String, dynamic>?> completedAssignment(
      int userId, String signature, DateTime day) async {
    for (final record in await load(userId)) {
      final ended =
          DateTime.tryParse(record['ended_at']?.toString() ?? '')?.toLocal();
      final started = DateTime.tryParse(record['started_at']?.toString() ?? '');
      final request = record['request'];
      if (record['server_submitted'] == true &&
          record['assignment_signature'] == signature &&
          request is Map &&
          request['user_id'] == userId &&
          ended != null &&
          started != null &&
          ended.year == day.year &&
          ended.month == day.month &&
          ended.day == day.day) {
        return record;
      }
    }
    return null;
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
