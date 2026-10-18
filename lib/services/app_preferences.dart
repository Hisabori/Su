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

  Future<void> setSpeechEnabled(bool enabled) =>
      store.write('suho_pref_speech_enabled', enabled ? 'true' : 'false');
}
