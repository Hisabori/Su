import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'local_store.dart';

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
      this.error});
  final int userId;
  final String partner, kiosk, name;
  final DateTime at;
  final num? current, capacity;
  final bool? available;
  final String? error;
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
        'error': error
      };
  factory DeviceReading.fromJson(Map<String, dynamic> data) => DeviceReading(
      userId: data['user_id'] as int,
      partner: data['partner'] as String,
      kiosk: data['kiosk'] as String,
      name: data['name'] as String,
      at: DateTime.parse(data['at'] as String),
      current: data['current'] is num ? data['current'] as num : null,
      capacity: data['capacity'] is num ? data['capacity'] as num : null,
      available: data['available'] is bool ? data['available'] as bool : null,
      error: data['error'] as String?);
}

class DeviceHistoryService {
  DeviceHistoryService({LocalStore? store})
      : store = store ?? const SecureLocalStore();
  final LocalStore store;
  static Future<void> _writes = Future<void>.value();
  String key(int userId, String partner, String kiosk) =>
      'device_history_${userId}_${sha256.convert(utf8.encode(jsonEncode([
            partner,
            kiosk
          ])))}';
  Future<List<DeviceReading>> load(
      int userId, String partner, String kiosk) async {
    final raw = await store.read(key(userId, partner, kiosk));
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    final records = values
        .map((r) => DeviceReading.fromJson(Map<String, dynamic>.from(r as Map)))
        .where((r) =>
            r.userId == userId && r.partner == partner && r.kiosk == kiosk)
        .toList();
    records.sort((a, b) => a.at.compareTo(b.at));
    return records;
  }

  Future<void> save(DeviceReading reading) {
    final result = _writes.then((_) async {
      final records =
          await load(reading.userId, reading.partner, reading.kiosk);
      records.add(reading);
      records.sort((a, b) => a.at.compareTo(b.at));
      final cutoff = reading.at.subtract(const Duration(days: 7));
      final kept = records.where((r) => !r.at.isBefore(cutoff)).toList();
      final bounded =
          kept.length > 1500 ? kept.sublist(kept.length - 1500) : kept;
      await store.write(key(reading.userId, reading.partner, reading.kiosk),
          jsonEncode(bounded.map((r) => r.toJson()).toList()));
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
