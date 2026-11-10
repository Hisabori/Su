import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'local_store.dart';
import 'diagnostic_log.dart';

class RecoveredRecords<T> {
  const RecoveredRecords(this.records, this.recovered);
  final List<T> records;
  final bool recovered;
}

/// Keep the exact damaged source before allowing a later save to replace it.
/// A failed backup blocks the write instead of discarding unrecoverable records.
Future<RecoveredRecords<T>> readRecoverableRecords<T>(LocalStore store,
    String key, T Function(Map<String, dynamic>) decode) async {
  final area =
      key.startsWith('device_history_') ? 'device_history' : 'work_history';
  List data;
  String? raw;
  try {
    raw = await store.read(key);
    if (raw == null) return RecoveredRecords(<T>[], false);
    final parsed = jsonDecode(raw);
    if (parsed is! List) throw const FormatException('Invalid record list');
    data = parsed;
  } catch (_) {
    DiagnosticLog.record(area, 'read_failed');
    rethrow;
  }
  final records = <T>[];
  var damaged = false;
  for (final row in data) {
    try {
      if (row is! Map) throw const FormatException('Invalid record');
      records.add(decode(Map<String, dynamic>.from(row)));
    } on FormatException {
      damaged = true;
    } on TypeError {
      damaged = true;
    }
  }
  if (damaged) {
    final digest = sha256.convert(utf8.encode(raw));
    try {
      await store.write('${key}_recovery_$digest', raw);
      DiagnosticLog.record(area, 'rows_recovered');
    } catch (_) {
      DiagnosticLog.record(area, 'backup_failed');
      rethrow;
    }
  }
  return RecoveredRecords(records, damaged);
}
