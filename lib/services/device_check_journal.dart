import 'dart:convert';
import '../models/device_check_record.dart';
import 'device_history_service.dart';

/// A work-local journal. It never calls an API or edits a submitted result.
class DeviceCheckJournal {
  DeviceCheckJournal(
      {required this.records, required this.keys, required this.persist});
  final List<Map<String, dynamic>> records;
  final List<String> keys;
  final Future<void> Function() persist;
  Future<void> _writes = Future<void>.value();
  bool persistenceFailed = false;

  Future<void> record(DeviceReading reading, {required int userId}) {
    final operation = _writes.then((_) async {
      if (reading.userId != userId ||
          reading.error != null ||
          reading.available == null ||
          reading.partner.isEmpty ||
          reading.kiosk.isEmpty ||
          (reading.available == true && reading.percent == null)) {
        return;
      }
      final key = jsonEncode([
        userId,
        reading.partner,
        reading.kiosk,
        reading.at.toUtc().toIso8601String()
      ]);
      if (!keys.contains(key)) {
        records.add(DeviceCheckRecord(
                name: reading.name,
                at: reading.at,
                available: reading.available!,
                current: reading.current,
                capacity: reading.capacity)
            .toResultJson());
        keys.add(key);
      }
      // A failed local write must not discard a valid in-memory observation.
      await _persist();
    });
    _writes =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _persist() async {
    try {
      await persist();
      persistenceFailed = false;
    } catch (_) {
      persistenceFailed = true;
    }
  }

  Future<void> flush() async {
    await _writes;
    if (persistenceFailed) await _persist();
  }
}
