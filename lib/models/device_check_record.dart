import 'work_result.dart' show formatDateTime;

/// Original DeviceCheckRecord.toResultJson / KioskCapacity.checkStatus contract.
class DeviceCheckRecord {
  const DeviceCheckRecord(
      {required this.name,
      required this.at,
      required this.available,
      required this.current,
      required this.capacity});
  final String name;
  final DateTime at;
  final bool available;
  final num? current, capacity;
  String get checkStatus {
    if (!available) return '사용 불가';
    final value = current, maximum = capacity;
    if (value == null ||
        maximum == null ||
        !value.isFinite ||
        !maximum.isFinite ||
        value < 0 ||
        maximum <= 0) {
      return '용량 미확인';
    }
    final percent = value / maximum * 100;
    return percent.isFinite ? '${percent.toStringAsFixed(1)}%' : '용량 미확인';
  }

  Map<String, dynamic> toResultJson() => {
        'type': 'device_check',
        'device_name': name,
        '기기상태체크': checkStatus,
        '시간': formatDateTime(at),
        'isAvailable': available,
      };
}
