import 'dart:convert';
import '../models/device_check_record.dart';
import '../models/work_result.dart';
import 'api_service.dart';
import 'device_history_service.dart';
import 'local_store.dart';
import 'kiosk_sync_lock.dart';
import 'kiosk_sync_scope.dart';

/// Explicitly scoped experiment. This is NOT an atomic server update.
/// A persisted pending operation blocks all further writes after uncertainty.
class KioskResultSync {
  KioskResultSync(this.api, {LocalStore? store})
      : store = store ?? const SecureLocalStore();
  final ApiService api;
  final LocalStore store;
  static bool _busy = false;
  static const key = 'kiosk_result_sync69_pending_v1';
  static const backupKey = 'kiosk_result_sync69_last_backup_v1';
  static String pendingKeyFor(int userId) =>
      userId == 69 ? key : 'kiosk_result_sync${userId}_pending_v1';
  static String backupKeyFor(int userId) =>
      userId == 69 ? backupKey : 'kiosk_result_sync${userId}_last_backup_v1';

  static String fingerprint(List<Map<String, dynamic>> rows) {
    dynamic canonical(dynamic value) {
      if (value is List) return value.map(canonical).toList();
      if (value is Map) {
        final keys = value.keys.map((k) => k.toString()).toList()..sort();
        return {for (final k in keys) k: canonical(value[k])};
      }
      return value;
    }

    return jsonEncode(canonical(rows
        .map((r) => {
              for (final e in r.entries)
                if (e.key != 'admin_name') e.key: e.value,
            })
        .toList()));
  }

  static Map<String, dynamic> candidate(
      Map<String, dynamic> row, DeviceReading reading) {
    final day = formatDate(reading.at);
    if (!KioskSyncScope.matches(
            reading.userId, reading.partner, reading.kiosk) ||
        row['user_id'] != reading.userId ||
        row['work_date'] != day ||
        reading.name.trim().isEmpty ||
        reading.error != null ||
        reading.available == null ||
        reading.percent == null ||
        row['result_id'] is! int ||
        row['work_id'] != KioskSyncScope.workId ||
        row['process_version_id'] is! int ||
        row['work_minutes'] is! num ||
        row['rest_minutes'] is! num) {
      throw ApiFailure('사용자·근무일·배정·기존 기록을 확인하지 못했습니다.');
    }
    String time(String field) {
      final raw = row[field];
      if (raw is! String) throw ApiFailure('실제 근무시간이 없습니다.');
      final value = raw.length == 8 ? '$day $raw' : raw;
      if (!value.startsWith('$day ') || DateTime.tryParse(value) == null) {
        throw ApiFailure('실제 근무시간을 확인하지 못했습니다.');
      }
      return value;
    }

    final start = time('actual_start_time'), end = time('actual_end_time');
    if (DateTime.parse(end).isBefore(DateTime.parse(start))) {
      throw ApiFailure('실제 근무시간이 올바르지 않습니다.');
    }
    final items = jsonDecode(row['result_json'] as String);
    if (items is! List || items.isEmpty || items.any((r) => r is! Map)) {
      throw ApiFailure('기존 업무 답변을 확인하지 못했습니다.');
    }
    final point = DeviceCheckRecord(
            name: reading.name,
            at: reading.at,
            available: reading.available!,
            current: reading.current,
            capacity: reading.capacity)
        .toResultJson();
    // Same second is representable only once in the original server format.
    final duplicate = items.any((r) =>
        r['type'] == 'device_check' &&
        r['device_name'] == point['device_name'] &&
        r['시간'] == point['시간'] &&
        r['기기상태체크'] == point['기기상태체크'] &&
        r['isAvailable'] == point['isAvailable']);
    return {
      'packetid':
          'kiosk_sync${reading.userId}_${reading.at.microsecondsSinceEpoch}',
      for (final field in [
        'user_id',
        'work_id',
        'process_version_id',
        'work_date',
        'work_minutes',
        'rest_minutes'
      ])
        field: row[field],
      'start_time': start,
      'end_time': end,
      'result_json': jsonEncode([...items, if (!duplicate) point]),
    };
  }

  Future<String?> sync(DeviceReading reading,
      {required bool workActive}) async {
    if (!KioskSyncScope.allows(reading.userId) ||
        await api.tokens.userId() != reading.userId) {
      return null;
    }
    if (!KioskSyncScope.matches(
            reading.userId, reading.partner, reading.kiosk) ||
        reading.error != null ||
        reading.available == null ||
        reading.percent == null) {
      return null;
    }
    if (workActive) return '근무 중 점검은 보관되며 근무 완료 시 전송합니다.';
    return withKioskSyncLock(reading.userId, () => _sync(reading));
  }

  Future<String?> _sync(DeviceReading reading) async {
    final operationKey = pendingKeyFor(reading.userId);
    final recoveryKey = backupKeyFor(reading.userId);
    if (_busy) return '이전 점검의 관리자 저장을 확인 중입니다.';
    _busy = true;
    try {
      if (await store.read(operationKey) != null) {
        return '이전 관리자 갱신의 복구 확인이 필요합니다. 자동 재전송을 중단했습니다.';
      }
      final day = formatDate(reading.at);
      final rows = await api.ownKioskResults(day, userId: reading.userId);
      if (rows.length != 1) {
        return rows.isEmpty
            ? '오늘 근무 결과가 없어 관리자 점검을 추가하지 않았습니다.'
            : '오늘 근무 결과가 여러 건이라 자동 갱신을 중단했습니다.';
      }
      final body = candidate(rows.single, reading);
      if (jsonEncode(jsonDecode(rows.single['result_json'] as String)) ==
          body['result_json']) {
        return '이 조회는 이미 관리자에 기록돼 있습니다.';
      }
      // Read-back verifies durable storage before any destructive call.
      final journal = jsonEncode({'before': rows, 'request': body});
      await store.write(recoveryKey, journal);
      if (await store.read(recoveryKey) != journal) {
        throw ApiFailure('복구 백업 저장 실패');
      }
      await store.write(operationKey, journal);
      if (await store.read(operationKey) != journal) {
        throw ApiFailure('복구 상태 저장 실패');
      }
      final current = await api.ownKioskResults(day, userId: reading.userId);
      if (fingerprint(current) != fingerprint(rows)) {
        await store.delete(operationKey); // No destructive request has started.
        return '다른 곳에서 근무 기록이 변경돼 갱신을 중단했습니다.';
      }
      await api.deleteOwnKioskDay(day,
          userId: reading.userId); // Never retry this request.
      if ((await api.ownKioskResults(day, userId: reading.userId)).isNotEmpty) {
        throw ApiFailure('삭제 후 상태가 예상과 다릅니다.');
      }
      final id =
          await api.submitWorkResult(body); // Never retry on uncertainty.
      final after = await api.ownKioskResults(day, userId: reading.userId);
      if (id == null || after.length != 1 || after.single['result_id'] != id) {
        throw ApiFailure('재등록 결과 확인 실패');
      }
      final result = after.single;
      for (final field in [
        'user_id',
        'work_id',
        'process_version_id',
        'work_date',
        'work_minutes',
        'rest_minutes'
      ]) {
        if (result[field] != body[field]) throw ApiFailure('재등록 데이터 대조 실패');
      }
      for (final pair in [
        ['actual_start_time', 'start_time'],
        ['actual_end_time', 'end_time']
      ]) {
        final raw = result[pair[0]];
        if ((raw is String && raw.length == 8 ? '$day $raw' : raw) !=
            body[pair[1]]) {
          throw ApiFailure('재등록 근무시간 대조 실패');
        }
      }
      if (jsonEncode(jsonDecode(result['result_json'] as String)) !=
          body['result_json']) {
        throw ApiFailure('재등록 점검 데이터 대조 실패');
      }
      await store.delete(operationKey);
      return '${reading.percentLabel} 관리자 기록 저장·대조 완료';
    } catch (_) {
      return '관리자 갱신을 완료하지 못했습니다. 복구 확인 전 자동 재시도하지 않습니다.';
    } finally {
      _busy = false;
    }
  }
}
