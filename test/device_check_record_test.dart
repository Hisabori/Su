import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/models/device_check_record.dart';
import 'package:suho_angel/models/work_info.dart';
import 'package:suho_angel/models/work_result.dart';

void main() {
  test(
      'original portal capacity column receives a percent, not an operational status',
      () {
    final at = DateTime(2026, 11, 19, 9, 12);
    for (final item in [
      (0, '0.0%'),
      (250, '25.0%'),
      (1000, '100.0%'),
      (1250, '125.0%')
    ]) {
      final check = DeviceCheckRecord(
              name: '수거기',
              at: at,
              available: true,
              current: item.$1,
              capacity: 1000)
          .toResultJson();
      final payload = WorkResultPayload(
          work: WorkInfo(id: '8', name: '업무', processVersionId: 1),
          userId: 31,
          start: at,
          end: at.add(const Duration(minutes: 3)),
          restSeconds: 0,
          answers: [],
          deviceChecks: [check]);
      final result =
          (jsonDecode(payload.request['result_json'] as String) as List)
              .cast<Map>()
              .where((row) => row['type'] == 'device_check')
              .single;
      expect(result, {
        'type': 'device_check',
        'device_name': '수거기',
        '기기상태체크': item.$2,
        '시간': '2026-11-19 09:12:00',
        'isAvailable': true,
        '업무내용': '기기체크'
      });
    }
  });
  test(
      'unavailable and invalid capacity retain their meanings instead of fake zero',
      () {
    final at = DateTime(2026, 11, 19);
    expect(
        DeviceCheckRecord(
                name: '수거기',
                at: at,
                available: false,
                current: 250,
                capacity: 1000)
            .checkStatus,
        '사용 불가');
    for (final values in [(null, 1000), (250, 0), (-1, 1000)]) {
      expect(
          DeviceCheckRecord(
                  name: '수거기',
                  at: at,
                  available: true,
                  current: values.$1,
                  capacity: values.$2)
              .checkStatus,
          '용량 미확인');
    }
  });
}
