import 'dart:convert';
import 'api_service.dart';
import 'token_storage_service.dart';
import 'passkey_platform.dart' as platform;

class PasskeyService {
  bool get enrolled => platform.passkeyEnrolled;
  void lock() => platform.passkeyLock();
  Future<Map<String, dynamic>> status() async =>
      _check(await platform.passkeyStatus());
  Map<String, dynamic> _check(Map<String, dynamic> result) {
    if (result['ok'] == true) return result;
    final code = result['code'];
    throw ApiFailure(switch (code) {
      'NotAllowedError' || 'AbortError' => '패스키 인증이 취소됐거나 시간이 초과됐습니다.',
      'unsupported' ||
      'prf_unsupported' =>
        '이 브라우저 또는 패스키 제공자는 세션 암호화(PRF)를 지원하지 않습니다. 비밀번호로 로그인해 주세요.',
      'different_account' => '현재 기기에 등록된 패스키는 다른 계정용입니다. 기존 설정을 해제한 뒤 등록해 주세요.',
      'invalid_vault' ||
      'credential_mismatch' =>
        '저장된 패스키 세션을 열지 못했습니다. 비밀번호로 로그인한 뒤 패스키 설정을 확인해 주세요.',
      'busy' => '진행 중인 패스키 인증을 먼저 완료해 주세요.',
      'already_enrolled' => '이미 패스키가 설정돼 있습니다. 로그인 정보 갱신을 선택해 주세요.',
      _ => '패스키 처리를 완료하지 못했습니다. 브라우저 설정과 기기 저장 공간을 확인해 주세요.',
    });
  }

  Future<void> enroll(TokenStorageService tokens, String label) async {
    final data = await tokens.snapshot();
    _check(await platform.passkeyEnroll(jsonEncode(data), label));
    try {
      await tokens.clearPersisted();
    } catch (_) {
      await platform.passkeyForget();
      rethrow;
    }
  }

  Future<void> unlock(ApiService api) async {
    _check(await platform.passkeyUnlock());
    try {
      await api.validateToken();
    } catch (_) {
      lock();
      throw ApiFailure(
          '저장된 로그인 세션을 서버에서 확인하지 못했습니다. 연결을 확인하거나 비밀번호로 다시 로그인해 주세요.');
    }
  }

  Future<void> refresh(TokenStorageService tokens) async => _check(
      await platform.passkeyRefresh(jsonEncode(await tokens.snapshot())));
  Future<void> disable(TokenStorageService tokens) async {
    final data = await tokens.snapshot();
    _check(await platform.passkeyForget());
    await tokens.restoreSnapshot(data);
  }
}
