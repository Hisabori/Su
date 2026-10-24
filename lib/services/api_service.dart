import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/community_config.dart';
import '../models/work_info.dart';
import '../utils/password_utils.dart';
import 'token_storage_service.dart';

class ApiFailure implements Exception {
  final String message;
  final int? code;
  ApiFailure(this.message, {this.code});
  @override
  String toString() => message;
}

class WorkStatusResponse extends ApiFailure {
  final Map<String, dynamic> response;
  WorkStatusResponse(this.response)
      : super(
            response['message'] is String &&
                    (response['message'] as String).trim().isNotEmpty
                ? (response['message'] as String).trim()
                : '현재 서버에서 새 작업을 시작할 수 없는 상태입니다. 근무 상태를 다시 확인해 주세요.',
            code: 7);
}

class ApiService {
  final http.Client client;
  final TokenStorageService tokens;
  final bool enabled, communityLogin;
  ApiService(
      {http.Client? client,
      TokenStorageService? tokens,
      this.enabled = true,
      this.communityLogin = false})
      : client = client ?? http.Client(),
        tokens = tokens ?? TokenStorageService();
  Uri _uri(String path) {
    if (!enabled) throw ApiFailure('서비스 연결이 비활성화되어 있습니다.');
    final uri = Uri.parse(ApiConfig.baseUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ApiFailure('서비스 주소를 확인해 주세요.');
    }
    return uri.resolve(path);
  }

  Map<String, dynamic> _decode(http.Response response, String path) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiFailure('로그인이 필요하거나 접근 권한이 없습니다.', code: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure('서버에 연결하지 못했습니다.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is String) data = jsonDecode(data);
    } on FormatException {
      throw ApiFailure('서비스 응답을 확인할 수 없습니다.');
    }
    if (data is! Map<String, dynamic>) throw ApiFailure('서비스 응답을 확인할 수 없습니다.');
    final ret = integer(data['ret']);
    // The APK handles work_info ret=7 as a work-status response, not a
    // transport/authentication rejection. Never apply this to result saving.
    if (path == ApiConfig.workInfoPath && ret == 7) {
      throw WorkStatusResponse(data);
    }
    if (!path.endsWith('/login') && ret != null && ret != 0 && ret != 1) {
      throw ApiFailure(
          data['message'] is String && (data['message'] as String).isNotEmpty
              ? data['message'] as String
              : '서버에서 요청을 거절했습니다. (응답 코드: $ret)',
          code: ret);
    }
    return data;
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final uri = _uri(path);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json'
    };
    if (auth) {
      final token = await tokens.read();
      if (token == null || token.isEmpty) throw ApiFailure('다시 로그인해 주세요.');
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await client
        .put(uri,
            headers: headers,
            body: jsonEncode({
              if (!uri.path.endsWith('/kiosk_info'))
                'packetid':
                    '${uri.path.split('/').last}_${DateTime.now().millisecondsSinceEpoch}',
              ...body
            }))
        .timeout(const Duration(seconds: 20));
    return _decode(response, path);
  }

  Future<Map<String, dynamic>> loginData(
      String username, String password) async {
    final body = {
      'username': username,
      'password': encodePassword(password, 'sha256')
    };
    if (communityLogin && enabled) {
      http.Response? response;
      try {
        response = await client
            .post(Uri.parse(CommunityConfig.endpoint),
                headers: {'Content-Type': 'application/json; charset=utf-8'},
                body: jsonEncode({'action': 'login', ...body}))
            .timeout(const Duration(seconds: 25));
      } on http.ClientException {
        /* Work login remains available if the community service is unreachable. */
      } on TimeoutException {
        /* A stalled community proxy must not prevent normal work login. */
      }
      if (response != null &&
          ![404, 405, 501, 502, 503, 504].contains(response.statusCode)) {
        return _decode(response, ApiConfig.loginPath);
      }
    }
    return _put(ApiConfig.loginPath, body, auth: false);
  }

  Future<void> login(String username, String password) async {
    // Previous app reconstruction documents SHA-256 lowercase hex and PUT.
    final data = await loginData(username, password);
    final ret = integer(data['ret']);
    if (ret != 1) {
      // Recovered AuthProvider.login branches at 0x428c5c–0x428d24.
      final message = switch (ret) {
        2 => '비밀번호가 올바르지 않습니다.',
        3 => '존재하지 않는 사용자입니다.',
        4 => '로그인 권한이 없습니다.',
        5 => '비활성화된 계정입니다. 관리자에게 문의하세요.',
        6 => '주말 또는 공휴일에는 근무를 시작할 수 없습니다.',
        _ => data['message'] is String &&
                (data['message'] as String).trim().isNotEmpty
            ? data['message'] as String
            : '서버에서 로그인 요청을 거절했습니다.',
      };
      throw ApiFailure('$message (응답 코드: ${ret ?? "미확인"})', code: ret);
    }
    final token = data['access_token'];
    final refresh = data['refresh_token'];
    final userId = integer(data['user_id']);
    if (token is! String ||
        token.isEmpty ||
        userId == null ||
        userId <= 0 ||
        (refresh != null && refresh is! String)) {
      throw ApiFailure('로그인 응답을 확인할 수 없습니다.');
    }
    await tokens.clear();
    try {
      await tokens.saveUserId(userId);
      await tokens.saveDevice(data);
      await tokens.save(token, refresh as String?);
    } catch (_) {
      await tokens.clear();
      rethrow;
    }
  }

  Future<WorkInfo> getWorkInfo() async {
    final userId = await tokens.userId();
    if (userId == null) throw ApiFailure('다시 로그인해 주세요.');
    return WorkInfo.fromJson(
        await _put(ApiConfig.workInfoPath, {'user_id': userId}));
  }

  // Fields recovered from WorkResultPayload::toRequestMap, not guessed.
  Future<int?> submitWorkResult(Map<String, dynamic> request) async {
    final userId = await tokens.userId();
    if (userId == null || request['user_id'] != userId) {
      throw ApiFailure('다시 로그인해 주세요.');
    }
    if (integer(request['process_version_id']) == null) {
      throw ApiFailure('업무 버전 정보가 없습니다.');
    }
    final result = await _put('/api/user/work_result', request);
    if (integer(result['ret']) != 1) throw ApiFailure('업무 결과 저장에 실패했습니다.');
    return integer(result['result_id']);
  }

  Future<Map<String, dynamic>> kioskInfo(String partnerId) =>
      _put('/api/admin/kiosk_info', {'partnerId': partnerId});
  Future<void> logout() async {
    final userId = await tokens.userId();
    try {
      if (userId != null) await _put('/api/user/logout', {'user_id': userId});
    } finally {
      await tokens.clear();
    }
  }

  Future<void> validateToken() async {
    final token = await tokens.read();
    if (token == null) throw ApiFailure('다시 로그인해 주세요.');
    final data = await _put('/api/user/validate_token', {'token': token});
    if (integer(data['ret']) != 1) {
      throw ApiFailure('다시 로그인해 주세요.', code: 401);
    }
  }

  Future<void> logoutLocally() => tokens.clear();
  void close() => client.close();
}
