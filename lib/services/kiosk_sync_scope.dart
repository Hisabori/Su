/// Explicit rollout list, verified against the server's kiosk assignments.
/// This client scope is not a replacement for server authorization.
class KioskSyncScope {
  static const partner = 'greenhug';
  static const workId = 2;
  static const kiosks = <int, String>{
    69: 'VixVL4sPtmkwPaGHBWoR',
    58: '05QzbVT2QtndWtyDQj0O',
    64: '05QzbVT2QtndWtyDQj0O',
    44: 'NerkOOJXXhIEOxEsONfS',
    81: 'Nfwj3VJuxUBdeNcI72ga',
    41: 'iXtg3zJq7KpJeZZUjwv1',
  };
  static bool allows(int? userId) => kiosks.containsKey(userId);
  static bool matches(int userId, String assignedPartner, String kiosk) =>
      allows(userId) && assignedPartner == partner && kiosks[userId] == kiosk;
}
