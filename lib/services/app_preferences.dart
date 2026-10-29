import 'local_store.dart';

class AppPreferences {
  final LocalStore store;
  AppPreferences({LocalStore? store})
      : store = store ?? const SecureLocalStore();
  Future<double> speechSpeed() async {
    try {
      final value =
          double.tryParse(await store.read('suho_pref_speech_speed') ?? '');
      return const [.85, 1.0, 1.1].contains(value) ? value! : 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> setSpeechSpeed(double value) => store.write(
      'suho_pref_speech_speed',
      (const [.85, 1.0, 1.1].contains(value) ? value : 1.0).toString());
  Future<bool> speechEnabled() async {
    try {
      return await store.read('suho_pref_speech_enabled') != 'false';
    } catch (_) {
      return true;
    }
  }

  Future<bool> betaEnabled() async {
    return !await legacyEnabled();
  }

  Future<bool> legacyEnabled() async {
    try {
      // The old opt-in flag must not keep existing installs in classic mode.
      return await store.read('suho_pref_legacy_enabled') == 'true';
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

  Future<void> setBetaEnabled(bool enabled) => setLegacyEnabled(!enabled);

  Future<void> setLegacyEnabled(bool enabled) =>
      store.write('suho_pref_legacy_enabled', enabled ? 'true' : 'false');

  Future<void> setSpeechEnabled(bool enabled) =>
      store.write('suho_pref_speech_enabled', enabled ? 'true' : 'false');
}
