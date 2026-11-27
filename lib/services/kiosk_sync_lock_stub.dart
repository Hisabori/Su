Future<String?> withKioskSyncLock(
        int userId, Future<String?> Function() action) =>
    action();
