import 'work_info.dart';
import 'work_schedule.dart';

/// A server schedule is separate from the time spent answering in the app.
class WorkHours {
  const WorkHours(this.start, this.end);
  final DateTime? start, end;
  factory WorkHours.forWork(WorkInfo work, DateTime day) {
    final start = WorkSchedule.timeOnDay(work.startTime, day);
    var end = WorkSchedule.timeOnDay(work.endTime, day);
    if (start != null && end != null && end.isBefore(start)) {
      if (RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$')
          .hasMatch(work.endTime?.trim() ?? '')) {
        end = DateTime(
            end.year, end.month, end.day + 1, end.hour, end.minute, end.second);
      } else {
        end = null;
      }
    }
    return WorkHours(start, end);
  }
  factory WorkHours.fromRecord(Map<String, dynamic> record) => WorkHours(
      DateTime.tryParse('${record['scheduled_start_at'] ?? ''}')?.toLocal(),
      DateTime.tryParse('${record['scheduled_end_at'] ?? ''}')?.toLocal());
  bool get isComplete => start != null && end != null;

  /// Fill missing bounds only; preserve the schedule captured for a receipt.
  WorkHours fillMissing(WorkHours fresh) =>
      WorkHours(start ?? fresh.start, end ?? fresh.end);

  Map<String, dynamic> get snapshot => {
        'schedule_source': 'server',
        'scheduled_start_at': start?.toUtc().toIso8601String(),
        'scheduled_end_at': end?.toUtc().toIso8601String(),
      };
  String get durationLabel {
    if (start == null || end == null || end!.isBefore(start!)) return '미확인';
    final minutes = end!.difference(start!).inMinutes,
        h = minutes ~/ 60,
        m = minutes % 60;
    if (h == 0) return '$m분';
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }
}
