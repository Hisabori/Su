import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'local_store.dart';
import 'record_recovery.dart';
import 'diagnostic_log.dart';
import 'api_service.dart';

class DeviceReading {
  const DeviceReading(
      {required this.userId,
      required this.partner,
      required this.kiosk,
      required this.name,
      required this.at,
      this.current,
      this.capacity,
      this.available,
      this.error,
      this.errorCode});
  final int userId;
  final String partner, kiosk, name;
  final DateTime at;
  final num? current, capacity;
  final bool? available;
  final String? error, errorCode;
  double? get percent {
    if (error != null ||
        current == null ||
        capacity == null ||
        !current!.isFinite ||
        !capacity!.isFinite ||
        current! < 0 ||
        capacity! <= 0) {
      return null;
    }
    final value = current! / capacity! * 100;
    return value.isFinite ? value : null;
  }

  String get percentLabel =>
      percent == null ? '용량 미확인' : '${percent!.toStringAsFixed(1)}%';
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'partner': partner,
        'kiosk': kiosk,
        'name': name,
        'at': at.toUtc().toIso8601String(),
        'current': current?.isFinite == true ? current : null,
        'capacity': capacity?.isFinite == true ? capacity : null,
        'available': available,
        'error': error,
        'error_code': errorCode
      };
  factory DeviceReading.fromJson(Map<String, dynamic> data) => DeviceReading(
      userId: int.parse('${data['user_id']}'),
      partner: data['partner'] as String,
      kiosk: data['kiosk'] as String,
      name: data['name'] as String,
      at: DateTime.parse(data['at'] as String),
      current: num.tryParse('${data['current']}'),
      capacity: num.tryParse('${data['capacity']}'),
      available: data['available'] is bool ? data['available'] as bool : null,
      error: data['error'] as String?,
      errorCode: data['error_code'] as String?);
}

class DeviceHistoryService {
  DeviceHistoryService(
      {LocalStore? store,
      this.remoteLoad,
      this.remoteSample,
      this.remoteLoadMore,
      this.remoteHasMore})
      : store = store ?? const SecureLocalStore();
  final Future<List<DeviceReading>?> Function()? remoteLoad, remoteLoadMore;
  final Future<bool> Function()? remoteSample;
  final bool Function()? remoteHasMore;
  bool cloudConnected = false, localStorageFailed = false;
  String? cloudReadError, cloudWriteError;
  String? get cloudError => cloudWriteError ?? cloudReadError;
  bool get hasMore => remoteHasMore?.call() == true;

  Future<List<DeviceReading>> loadMore() async =>
      (await remoteLoadMore?.call()) ?? [];
  final LocalStore store;
  bool historyRecovered = false;
  static Future<void> _writes = Future<void>.value();
  String key(int userId, String partner, String kiosk) =>
      'device_history_${userId}_${sha256.convert(utf8.encode(jsonEncode([
            partner,
            kiosk
          ])))}';
  Future<List<DeviceReading>> load(
      int userId, String partner, String kiosk) async {
    if (remoteLoad != null) {
      try {
        final remote = await remoteLoad!();
        if (remote != null) {
          cloudConnected = true;
          cloudReadError = null;
          return remote
              .where((r) =>
                  r.userId == userId &&
                  r.partner == partner &&
                  r.kiosk == kiosk)
              .toList();
        }
      } catch (e) {
        cloudConnected = false;
        cloudReadError =
            e is ApiFailure ? e.message : '서버 기록을 확인하지 못했습니다. [DVC-204]';
        DiagnosticLog.record('device_history', 'read_failed');
      }
    }
    return _loadLocal(userId, partner, kiosk);
  }

  Future<List<DeviceReading>> _loadLocal(
      int userId, String partner, String kiosk) async {
    final recovered = await readRecoverableRecords<DeviceReading>(
        store, key(userId, partner, kiosk), DeviceReading.fromJson);
    historyRecovered = recovered.recovered;
    final records = recovered.records
        .where((r) =>
            r.userId == userId && r.partner == partner && r.kiosk == kiosk)
        .toList();
    records.sort((a, b) => a.at.compareTo(b.at));
    return records;
  }

  Future<void> save(DeviceReading reading) {
    final result = _writes.then((_) async {
      Object? localError;
      StackTrace? localStack;
      try {
        final records =
            await _loadLocal(reading.userId, reading.partner, reading.kiosk);
        records.add(reading);
        records.sort((a, b) => a.at.compareTo(b.at));
        final cutoff = reading.at.subtract(const Duration(days: 7));
        final kept = records.where((r) => !r.at.isBefore(cutoff)).toList();
        final bounded =
            kept.length > 1500 ? kept.sublist(kept.length - 1500) : kept;
        await store.write(key(reading.userId, reading.partner, reading.kiosk),
            jsonEncode(bounded.map((r) => r.toJson()).toList()));
        localStorageFailed = false;
      } catch (error, stack) {
        localStorageFailed = true;
        localError = error;
        localStack = stack;
      }
      var cloudSaved = false;
      try {
        cloudSaved = await remoteSample?.call() ?? false;
        if (cloudSaved) {
          cloudConnected = true;
          cloudWriteError = null;
        }
      } catch (e) {
        cloudWriteError =
            e is ApiFailure ? e.message : '서버 기록을 저장하지 못했습니다. [DVC-202]';
        DiagnosticLog.record('device_history', 'save_failed');
      }
      if (localError != null && !cloudSaved) {
        Error.throwWithStackTrace(localError, localStack!);
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

/// Foreground polling never fills missed intervals with invented readings.
class DeviceMonitor extends ChangeNotifier {
  DeviceMonitor(
      {required this.fetch, required this.history, DateTime Function()? now})
      : now = now ?? DateTime.now;
  final Future<DeviceReading?> Function() fetch;
  final DeviceHistoryService history;
  final DateTime Function() now;
  static const interval = Duration(minutes: 10);
  DateTime? lastAttempt;
  DeviceReading? latest;
  bool fetching = false, storageFailed = false, _disposed = false;
  Future<DeviceReading?> poll(
      {bool force = false, bool foreground = true}) async {
    if (_disposed ||
        !foreground ||
        fetching ||
        (!force &&
            lastAttempt != null &&
            now().difference(lastAttempt!) < interval)) {
      return null;
    }
    fetching = true;
    lastAttempt = now();
    notifyListeners();
    try {
      final reading = await fetch();
      if (reading == null) return null;
      latest = reading;
      storageFailed = false;
      try {
        await history.save(reading);
      } catch (_) {
        storageFailed = true;
        DiagnosticLog.record('device_history', 'save_failed');
      }
      return reading;
    } finally {
      fetching = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
