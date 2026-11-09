import '../services/device_history_service.dart';

List<DeviceReading> devicePeriodReadings(Iterable<DeviceReading> records,
    {required DateTime now, required bool week}) {
  final local = now.toLocal();
  final start = week
      ? now.subtract(const Duration(days: 7))
      : DateTime(local.year, local.month, local.day);
  return records
      .where((r) => !r.at.isBefore(start) && !r.at.isAfter(now))
      .toList();
}

class DevicePeriodSummary {
  DevicePeriodSummary(Iterable<DeviceReading> readings) {
    for (final reading in readings) {
      final value = reading.percent;
      if (value == null) {
        unknown++;
        continue;
      }
      valid++;
      // Incremental mean avoids overflow when adding large finite readings.
      average = (average ?? value) + (value - (average ?? value)) / valid;
      if (maximum == null || value > maximum!) maximum = value;
    }
  }
  int valid = 0, unknown = 0;
  double? average, maximum;
  static String percent(double? value) =>
      value == null ? '측정 전' : '${value.toStringAsFixed(1)}%';
}
