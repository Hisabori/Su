import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/work_info.dart';
import '../utils/password_utils.dart';
import 'token_storage_service.dart';

class ApiFailure implements Exception {
  final String message;
  ApiFailure(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final http.Client client;
  final TokenStorageService tokens;
  final bool enabled;
  ApiService(
      {http.Client? client, TokenStorageService? tokens, this.enabled = true})
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

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiFailure('로그인이 필요하거나 접근 권한이 없습니다.');
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
    if (ret != null && ret != 0 && ret != 1) {
      throw ApiFailure(
          data['message'] is String && (data['message'] as String).isNotEmpty
              ? data['message'] as String
              : '요청이 거절되었습니다. 로그인 정보와 이용 가능 시간을 확인해 주세요.');
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
    return _decode(response);
  }

  Future<void> login(String username, String password) async {
    // Previous app reconstruction documents SHA-256 lowercase hex and PUT.
    final data = await _put(ApiConfig.loginPath,
        {'username': username, 'password': encodePassword(password, 'sha256')},
        auth: false);
    if (integer(data['ret']) != 1) throw ApiFailure('로그인 요청이 거절되었습니다.');
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
    if (integer(data['ret']) != 1) throw ApiFailure('다시 로그인해 주세요.');
  }

  Future<void> logoutLocally() => tokens.clear();
  void close() => client.close();
}
