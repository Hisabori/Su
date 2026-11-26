Future<String?> withKioskSyncLock(Future<String?> Function() action) =>
    action();
