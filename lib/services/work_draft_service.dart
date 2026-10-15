import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/work_info.dart';
import 'local_store.dart';

/// An origin/device-local checkpoint, never an automatic server submission.
class WorkDraftService {
  final LocalStore store;
  Future<void> _writes = Future<void>.value();
  WorkDraftService({LocalStore? store})
      : store = store ?? const SecureLocalStore();

  String signature(WorkInfo work) => sha256
      .convert(utf8.encode(jsonEncode([
        work.id,
        work.processVersionId,
        work.startTime,
        work.workMinutes,
        work.restMinutes,
        work.steps
            .map((s) => [
                  s.id,
                  s.order,
                  s.startTime,
                  s.workSeconds,
                  s.prompt,
                  s.questions,
                  s.videoPath
                ])
            .toList(),
      ])))
      .toString();

  Future<void> _queue(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> save(int user, WorkInfo work, Map<String, dynamic> state) {
    final snapshot = jsonEncode({
      'schema': 1,
      'user': user,
      'signature': signature(work),
      'state': state
    });
    return _queue(() => store.write('recovery_work_draft_$user', snapshot));
  }

  Future<Map<String, dynamic>?> load(int user, WorkInfo work,
      {DateTime? now}) async {
    final raw = await store.read('recovery_work_draft_$user');
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['schema'] != 1 ||
          value['user'] != user ||
          value['signature'] != signature(work)) {
        return null;
      }
      final state = value['state'] as Map<String, dynamic>;
      final index = state['index'] as int;
      final question = state['question_index'] as int;
      if (index < 0 ||
          index >= work.steps.length ||
          question < 0 ||
          question >=
              (work.steps[index].questions.isEmpty
                  ? 1
                  : work.steps[index].questions.length)) {
        return null;
      }
      final start = DateTime.parse(state['started_at'] as String);
      DateTime.parse(state['step_started_at'] as String);
      final anchor = DateTime.parse(state['schedule_anchor'] as String);
      final time = now ?? DateTime.now();
      if (start.isAfter(time.add(const Duration(minutes: 5))) ||
          anchor.isAfter(start.add(const Duration(minutes: 5)))) {
        return null;
      }
      if (state['pending_record'] == null &&
          time.difference(anchor) > const Duration(hours: 4)) {
        return null;
      }
      for (final key in ['rest_seconds', 'step_rest_seconds']) {
        if (state[key] is! int || (state[key] as int) < 0) {
          return null;
        }
      }
      for (final key in ['answers', 'device_checks']) {
        if (state[key] is! List ||
            (state[key] as List).any((a) => a is! Map<String, dynamic>)) {
          return null;
        }
      }
      for (final key in ['rest_started_at', 'rest_until']) {
        if (state[key] != null) DateTime.parse(state[key] as String);
      }
      if ((state['rest_started_at'] == null) != (state['rest_until'] == null)) {
        return null;
      }
      if (state['rest_started_at'] != null &&
          DateTime.parse(state['rest_until'] as String)
              .isBefore(DateTime.parse(state['rest_started_at'] as String))) {
        return null;
      }
      if (state['pending_record'] != null) {
        final record = state['pending_record'] as Map<String, dynamic>;
        final request = record['request'] as Map<String, dynamic>;
        if (request['user_id'] != user ||
            request['packetid'] != record['record_id']) {
          return null;
        }
      }
      return state;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clear(int user) =>
      _queue(() => store.delete('recovery_work_draft_$user'));
}
