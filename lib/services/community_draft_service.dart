import 'dart:convert';
import 'local_store.dart';

/// One text draft per authenticated account, stored only on this device.
class CommunityDraftService {
  CommunityDraftService({LocalStore? store})
      : store = store ?? const SecureLocalStore();
  final LocalStore store;
  static Future<void> _writes = Future<void>.value();
  Future<Map<String, dynamic>?> load(int user) async {
    await _writes;
    final raw = await store.read('community_draft_$user');
    if (raw == null) return null;
    final d = jsonDecode(raw);
    if (d is! Map<String, dynamic> ||
        d['title'] is! String ||
        d['body'] is! String) {
      return null;
    }
    return d;
  }

  Future<void> save(int user, String title, String body) =>
      _queue(() => store.write(
          'community_draft_$user', jsonEncode({'title': title, 'body': body})));
  Future<void> clear(int user) =>
      _queue(() => store.delete('community_draft_$user'));
  Future<void> _queue(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
