import 'dart:convert';
import 'work_info.dart';

String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';

class WorkResultPayload {
  final Map<String, dynamic> request;
  WorkResultPayload(
      {required WorkInfo work,
      required int userId,
      required DateTime start,
      required DateTime end,
      required int restSeconds,
      required List<Map<String, dynamic>> answers,
      required List<Map<String, dynamic>> deviceChecks})
      : request = {
          'packetid': 'work_result_${DateTime.now().millisecondsSinceEpoch}',
          'work_id': int.parse(work.id),
          'user_id': userId,
          'process_version_id': work.processVersionId,
          'work_date': formatDate(end),
          'start_time': formatDateTime(start),
          'end_time': formatDateTime(end),
          'work_minutes': (end.difference(start).inSeconds / 60).ceil(),
          'rest_minutes': (restSeconds / 60).ceil(),
          'result_json': jsonEncode([
            ...answers.map((a) => {
                  'stepid': integer(a['step_id']) ?? 0,
                  '시작시간':
                      formatDateTime(DateTime.parse(a['started_at'] as String)),
                  '종료시간':
                      formatDateTime(DateTime.parse(a['ended_at'] as String)),
                  '시간': (((integer(a['work_seconds']) ?? 0) / 60).ceil())
                      .clamp(1, 1440),
                  '비고': ['yes', 'video_completed', 'auto_completed']
                          .contains(a['answer'])
                      ? 1
                      : 0,
                }),
            ...deviceChecks,
          ]),
        };
}
