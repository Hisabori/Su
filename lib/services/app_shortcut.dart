/// Only local, predefined destinations are accepted from installed PWA shortcuts.
class AppShortcut {
  static bool _consumed = false;
  static String? take() {
    if (_consumed) return null;
    final target = Uri.base.queryParameters['shortcut'];
    if (!const {'collector', 'history', 'community'}.contains(target)) {
      return null;
    }
    _consumed = true;
    return target;
  }
}
