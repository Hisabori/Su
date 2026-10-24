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
  test('beta style requires opt-in and remembers both choices', () async {
    final store = MemoryStore();
    final preferences = AppPreferences(store: store);
    expect(await preferences.betaEnabled(), isFalse);
    await preferences.setBetaEnabled(true);
    expect(await AppPreferences(store: store).betaEnabled(), isTrue);
    await preferences.setBetaEnabled(false);
    expect(await AppPreferences(store: store).betaEnabled(), isFalse);
    expect(await AppPreferences(store: BrokenStore()).betaEnabled(), isFalse);
  });
  test('unavailable storage uses default; failed save is reported', () async {
    final preferences = AppPreferences(store: BrokenStore());
    expect(await preferences.speechEnabled(), isTrue);
    await expectLater(preferences.setSpeechEnabled(false), throwsStateError);
  });
}
