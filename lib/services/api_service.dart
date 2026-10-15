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
  ApiService({http.Client? client, TokenStorageService? tokens})
      : client = client ?? http.Client(),
        tokens = tokens ?? TokenStorageService();
  void _requireContract() {
    if (!ApiConfig.contractVerified) {
      throw ApiFailure('서비스 연결 준비 중입니다. 관리자에게 문의해 주세요.');
    }
  }

  Uri _uri(String path) {
    final base = Uri.parse(ApiConfig.baseUrl);
    if (base.scheme != 'https' || base.host.isEmpty) {
      throw ApiFailure('서비스 주소를 확인해 주세요.');
    }
    return base.resolve(path);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiFailure('로그인이 필요하거나 접근 권한이 없습니다.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      throw ApiFailure('서비스 응답을 확인할 수 없습니다.');
    }
    throw ApiFailure('서비스 응답을 확인할 수 없습니다.');
  }

  // ASSUMPTION: POST JSON username/password, access_token/refresh_token.
  // Verify against server before enabling API_CONTRACT_VERIFIED.
  Future<void> login(String username, String password) async {
    _requireContract();
    final encoded = encodePassword(password, ApiConfig.passwordEncoding);
    final response = await client
        .post(
          _uri(ApiConfig.loginPath),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': encoded}),
        )
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final token = data['access_token'];
    final refresh = data['refresh_token'];
    if (token is! String ||
        token.isEmpty ||
        (refresh != null && refresh is! String)) {
      throw ApiFailure('로그인 응답을 확인할 수 없습니다.');
    }
    await tokens.save(token, refresh as String?);
  }

  // ASSUMPTION: GET + Bearer, direct work object or work_info wrapper.
  Future<WorkInfo> getWorkInfo() async {
    _requireContract();
    final token = await tokens.read();
    if (token == null) throw ApiFailure('다시 로그인해 주세요.');
    final response = await client.get(
      _uri(ApiConfig.workInfoPath),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final work = data['work_info'] ?? data;
    if (work is! Map<String, dynamic>) {
      throw ApiFailure('작업 정보를 확인할 수 없습니다.');
    }
    return WorkInfo.fromJson(work);
  }

  Future<void> logoutLocally() => tokens.clear();
  void close() => client.close();
}
