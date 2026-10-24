import 'local_store.dart';

class AppPreferences {
  final LocalStore store;
  AppPreferences({LocalStore? store})
      : store = store ?? const SecureLocalStore();
  Future<bool> speechEnabled() async {
    try {
      return await store.read('suho_pref_speech_enabled') != 'false';
    } catch (_) {
      return true;
    }
  }

  Future<bool> betaEnabled() async {
    try {
      return await store.read('suho_pref_beta_enabled') == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<bool> autoLoginEnabled() async {
    try {
      return await store.read('suho_pref_auto_login') != 'false';
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoLoginEnabled(bool enabled) =>
      store.write('suho_pref_auto_login', enabled ? 'true' : 'false');

  Future<void> setBetaEnabled(bool enabled) =>
      store.write('suho_pref_beta_enabled', enabled ? 'true' : 'false');

  Future<void> setSpeechEnabled(bool enabled) =>
      store.write('suho_pref_speech_enabled', enabled ? 'true' : 'false');
}
