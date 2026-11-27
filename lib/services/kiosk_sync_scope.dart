/// All authenticated owners may sync, but only server-confirmed assignments.
/// This client check is not a replacement for server authorization.
class KioskSyncScope {
  static bool allows(int? userId) => userId != null && userId > 0;
  static bool matches(int userId, String assignedPartner, String kiosk) =>
      allows(userId) &&
      assignedPartner.trim().isNotEmpty &&
      kiosk.trim().isNotEmpty;

  static Set<int> assignedWorkIds(Map kiosk, int userId) {
    final workers = kiosk['assignedWorkers'];
    if (!allows(userId) || workers is! List) return {};
    return workers
        .whereType<Map>()
        .where((w) => int.tryParse('${w['user_id']}') == userId)
        .map((w) => int.tryParse('${w['work_id']}'))
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
  }
}
