import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/device_check_journal.dart';
import 'package:suho_angel/services/device_history_service.dart';

DeviceReading sample(
        {String kiosk = 'pet',
        DateTime? at,
        int user = 69,
        String? error,
        bool? available = true,
        num? current = 12,
        num? capacity = 1000}) =>
    DeviceReading(
        userId: user,
        partner: 'partner',
        kiosk: kiosk,
        name: '동일 이름',
        at: at ?? DateTime(2026, 11, 19, 9, 1, 35),
        current: current,
        capacity: capacity,
        available: available,
        error: error);
void main() {
  test(
      'replay is deduplicated; different kiosk and distinct query time are retained',
      () async {
    final records = <Map<String, dynamic>>[], keys = <String>[];
    final journal =
        DeviceCheckJournal(records: records, keys: keys, persist: () async {});
    await journal.record(sample(), userId: 69);
    await journal.record(sample(), userId: 69);
    await journal.record(sample(kiosk: 'other'), userId: 69);
    await journal.record(sample(at: DateTime(2026, 11, 19, 9, 1, 35, 100)),
        userId: 69);
    expect(records.length, 3);
    expect(keys.toSet().length, 3);
    expect(records.first['기기상태체크'], '1.2%');
    expect(records.first['업무내용'], '기기체크');
  });
  test(
      'queued simultaneous checks are not dropped while a checkpoint is pending',
      () async {
    final records = <Map<String, dynamic>>[], keys = <String>[];
    final started = Completer<void>(), gate = Completer<void>();
    var writes = 0;
    final journal = DeviceCheckJournal(
        records: records,
        keys: keys,
        persist: () async {
          if (++writes == 1) {
            started.complete();
            await gate.future;
          }
        });
    final first = journal.record(sample(), userId: 69);
    await started.future;
    final second = journal.record(sample(kiosk: 'other'), userId: 69);
    expect(records.length, 1);
    gate.complete();
    await Future.wait([first, second]);
    await journal.flush();
    expect(records.length, 2);
    expect(writes, 2);
  });
  test(
      'storage failure retains observations; retry and restored keys do not duplicate them',
      () async {
    final records = <Map<String, dynamic>>[], keys = <String>[];
    var down = true;
    String? snapshot;
    final journal = DeviceCheckJournal(
        records: records,
        keys: keys,
        persist: () async {
          if (down) throw StateError('storage');
          snapshot = jsonEncode({'checks': records, 'keys': keys});
        });
    await journal.record(sample(), userId: 69);
    expect(journal.persistenceFailed, isTrue);
    expect(records.length, 1);
    down = false;
    await journal.flush();
    expect(journal.persistenceFailed, isFalse);
    final saved = jsonDecode(snapshot!) as Map;
    final restored = DeviceCheckJournal(
        records: (saved['checks'] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        keys: (saved['keys'] as List).cast<String>(),
        persist: () async {});
    await restored.record(sample(), userId: 69);
    expect(restored.records.length, 1);
  });
  test(
      'network errors, unknown availability and foreign user cannot replace earlier checks',
      () async {
    final records = <Map<String, dynamic>>[], keys = <String>[];
    final journal =
        DeviceCheckJournal(records: records, keys: keys, persist: () async {});
    await journal.record(sample(), userId: 69);
    for (final reading in [
      sample(error: 'offline'),
      sample(available: null),
      sample(current: null),
      sample(user: 53)
    ]) {
      await journal.record(reading, userId: 69);
    }
    expect(records.length, 1);
    await journal.record(
        sample(
            available: false,
            current: null,
            capacity: null,
            at: DateTime(2026, 11, 19, 9, 2)),
        userId: 69);
    expect(records.last['기기상태체크'], '사용 불가');
  });
}
