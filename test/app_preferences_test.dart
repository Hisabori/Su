import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/app_preferences.dart';
import 'package:suho_angel/services/local_store.dart';
import 'storage_submission_test.dart' show MemoryStore;

class BrokenStore extends MemoryStore implements LocalStore {
  @override
  Future<String?> read(String key) async => throw StateError('unavailable');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('full');
}

void main() {
  test('color mode persists, rejects invalid values and falls back to system',
      () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.colorMode(), 'system');
    await preferences.setColorMode('dark');
    expect(await AppPreferences(store: store).colorMode(), 'dark');
    await preferences.setColorMode('invalid');
    expect(await preferences.colorMode(), 'system');
    expect(await AppPreferences(store: BrokenStore()).colorMode(), 'system');
  });

  test('reading speed persists and rejects unsupported values', () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.speechSpeed(), 1.0);
    await preferences.setSpeechSpeed(.85);
    expect(await AppPreferences(store: store).speechSpeed(), .85);
    await preferences.setSpeechSpeed(999);
    expect(await preferences.speechSpeed(), 1.0);
    expect(await AppPreferences(store: BrokenStore()).speechSpeed(), 1.0);
  });

  test(
      'automatic login choice persists and storage failures disable restoration',
      () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.autoLoginEnabled(), true);
    await preferences.setAutoLoginEnabled(false);
    expect(await AppPreferences(store: store).autoLoginEnabled(), false);
    expect(
        await AppPreferences(store: BrokenStore()).autoLoginEnabled(), false);
  });

  test('automatic reading defaults on and saved choice survives new instance',
      () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.speechEnabled(), isTrue);
    await preferences.setSpeechEnabled(false);
    expect(await AppPreferences(store: store).speechEnabled(), isFalse);
    await preferences.setSpeechEnabled(true);
    expect(await AppPreferences(store: store).speechEnabled(), isTrue);
  });
  test(
      'glass is default, old beta choices are ignored, explicit legacy choice persists',
      () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.betaEnabled(), isTrue);
    store.data['suho_pref_beta_enabled'] = 'false';
    expect(await preferences.betaEnabled(), isTrue);
    expect(await preferences.legacyEnabled(), isFalse);
    await preferences.setBetaEnabled(true);
    expect(await AppPreferences(store: store).betaEnabled(), isTrue);
    await preferences.setBetaEnabled(false);
    expect(await AppPreferences(store: store).betaEnabled(), isFalse);
    expect(await AppPreferences(store: store).legacyEnabled(), isTrue);
    expect(await AppPreferences(store: BrokenStore()).betaEnabled(), isTrue);
  });
  test('unavailable storage uses default; failed save is reported', () async {
    final preferences = AppPreferences(store: BrokenStore());
    expect(await preferences.speechEnabled(), isTrue);
    await expectLater(preferences.setSpeechEnabled(false), throwsStateError);
  });
}
