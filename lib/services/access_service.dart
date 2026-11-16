import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../utils/client_platform.dart';
import 'api_service.dart';
import 'diagnostic_log.dart';
import 'token_storage_service.dart';

class AccessService {
  AccessService({http.Client? client, TokenStorageService? tokens})
      : client = client ?? http.Client(),
        tokens = tokens ?? TokenStorageService();
  final http.Client client;
  final TokenStorageService tokens;
  String eventId = _eventId();
  void startEvent() => eventId = _eventId();
  static String _eventId() {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String get platform => clientPlatform;
  static const endpoint = String.fromEnvironment('ACCESS_API_URL',
      defaultValue: 'https://suho-angel.vercel.app/api/access');
  Future<Map<String, dynamic>> _request(Map<String, dynamic> body) async {
    final token = await tokens.read();
    if (token == null) throw ApiFailure('접속 기록 인증이 필요합니다. [ACC-001]');
    Map<String, dynamic> profile = {};
    try {
      profile = await tokens.device();
    } catch (_) {
      // Optional device metadata must not prevent verified-token access logging.
    }
    final session = profile['community_session'];
    http.Response response;
    try {
      response = await client
          .post(Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': 'Bearer $token',
                if (session is String && session.isNotEmpty)
                  'X-Community-Session': session,
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw ApiFailure('접속 기록 서버 연결이 지연되고 있습니다. [ACC-203]');
    }
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    } catch (_) {
      throw ApiFailure('접속 기록 응답을 확인하지 못했습니다. [ACC-204]');
    }
    final code = data['error_code'];
    if (response.statusCode != 200 || data['access_recorded'] == false) {
      final safe = code is String && RegExp(r'^ACC-\d{3}$').hasMatch(code)
          ? code
          : 'ACC-202';
      throw ApiFailure(
          '${data['message'] is String ? data['message'] : '접속 기록을 저장하지 못했습니다.'} [$safe]',
          code: response.statusCode);
    }
    return data;
  }

  Future<void> recordOpen() async {
    final data = await _request({
      'action': 'open',
      'event_id': eventId,
      'client': platform,
      'trace': DiagnosticLog.traceId
    });
    if (data['access_recorded'] != true) {
      throw ApiFailure('접속 기록 저장을 확인하지 못했습니다. [ACC-202]');
    }
  }

  Future<Map<String, dynamic>> list({String? cursor}) =>
      _request({'action': 'list', if (cursor != null) 'cursor': cursor});
  void close() => client.close();
}
