import 'api_service.dart';
import 'work_log_service.dart';

class SubmissionOutcome {
  final int? resultId;
  final bool persistedLocally;
  const SubmissionOutcome(this.resultId, this.persistedLocally);
}

class ResultSubmissionService {
  static final Map<String, Future<SubmissionOutcome>> _inFlight = {};
  final ApiService api;
  final WorkLogService logs;
  ResultSubmissionService(this.api, this.logs);

  Future<SubmissionOutcome> send(
      int userId, Map<String, dynamic> record) async {
    final id = record['record_id'];
    final request = record['request'];
    if (id is! String ||
        id.isEmpty ||
        request is! Map ||
        request['packetid'] != id) {
      throw ApiFailure('전송할 작업 기록을 확인할 수 없습니다.');
    }
    if (await api.tokens.userId() != userId || request['user_id'] != userId) {
      throw ApiFailure('현재 로그인한 사용자의 기록만 전송할 수 있습니다.');
    }
    final key = '${logs.scope}/$userId/$id';
    final active = _inFlight[key];
    if (active != null) return active;
    final pending = _send(userId, record);
    _inFlight[key] = pending;
    try {
      return await pending;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<SubmissionOutcome> _send(
      int userId, Map<String, dynamic> record) async {
    final confirmed = await logs.receipt(userId, record['record_id'] as String);
    if (confirmed != null) return SubmissionOutcome(confirmed.resultId, true);
    // Persist before the request; never automatically retry a write after a timeout.
    await logs.save(userId, record);
    final resultId = await api
        .submitWorkResult(Map<String, dynamic>.from(record['request'] as Map));
    final persisted = await logs.confirm(userId, record, resultId);
    return SubmissionOutcome(resultId, persisted);
  }
}
