import 'api_service.dart';
import 'app_preferences.dart';

enum SessionRestoreResult { disabled, missing, restored, expired }

/// Restores an existing session only; it never retains a password or skips
/// server verification. Locked passkey vaults return no readable token.
class SessionRestoreService {
  SessionRestoreService({required this.api, required this.preferences});
  final ApiService api;
  final AppPreferences preferences;

  Future<SessionRestoreResult> restore() async {
    if (!await preferences.autoLoginEnabled()) {
      return SessionRestoreResult.disabled;
    }
    final token = await api.tokens.read();
    if (token == null || token.isEmpty) return SessionRestoreResult.missing;
    final userId = await api.tokens.userId();
    if (userId == null || userId <= 0) {
      await api.tokens.clear();
      return SessionRestoreResult.expired;
    }
    try {
      await api.validateToken();
      if (await api.tokens.read() != token ||
          await api.tokens.userId() != userId) {
        return SessionRestoreResult.missing;
      }
      return SessionRestoreResult.restored;
    } on ApiFailure catch (e) {
      if (e.code != 401 && e.code != 403) rethrow;
      // Do not erase a newer session if the current account changed meanwhile.
      if (await api.tokens.read() == token &&
          await api.tokens.userId() == userId) {
        await api.tokens.clear();
      }
      return SessionRestoreResult.expired;
    }
  }
}
