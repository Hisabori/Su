import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/community_config.dart';
import 'api_service.dart';
import 'token_storage_service.dart';
import 'diagnostic_log.dart';

class CommunityService {
  final http.Client client;
  final TokenStorageService tokens;
  CommunityService({http.Client? client, TokenStorageService? tokens})
      : client = client ?? http.Client(),
        tokens = tokens ?? TokenStorageService();
  Future<Map<String, dynamic>> request(String action,
      [Map<String, dynamic> data = const {}]) async {
    final collector = action.startsWith('device_');
    final token = await tokens.read();
    final session = (await tokens.device())['community_session'];
    if (token == null || session is! String || session.isEmpty) {
      throw ApiFailure(collector
          ? '서버 수거기 기록 연결을 위해 근무를 마친 뒤 다시 로그인해 주세요. [DVC-001]'
          : '커뮤니티를 이용하려면 다시 로그인해 주세요. 진행 중인 근무는 먼저 마무리해 주세요.');
    }
    final http.Response response;
    try {
      response = await client
          .post(Uri.parse(CommunityConfig.endpoint),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': 'Bearer $token',
                'X-Community-Session': session,
                if (collector) 'X-Diagnostic-Trace': DiagnosticLog.traceId,
              },
              body: jsonEncode({'action': action, ...data}))
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ApiFailure(collector
          ? '서버 수거기 기록에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요. [DVC-203]'
          : '커뮤니티에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.');
    }
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiFailure(collector
          ? '서버 기록 응답을 확인하지 못했습니다. [DVC-204]'
          : '커뮤니티 응답을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    if (body is! Map<String, dynamic>) {
      throw ApiFailure(collector
          ? '서버 기록 응답을 확인하지 못했습니다. [DVC-204]'
          : '커뮤니티 응답을 확인하지 못했습니다.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
          '${body['message'] is String ? body['message'] : '요청을 완료하지 못했습니다.'}${body['error_code'] is String && RegExp(r'^DVC-\d{3}$').hasMatch(body['error_code']) ? ' [${body['error_code']}]' : ''}',
          code: response.statusCode);
    }
    return body;
  }

  void close() => client.close();
}
