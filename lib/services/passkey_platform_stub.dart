bool get passkeyEnrolled => false;
String? passkeyRead(String key) => null;
void passkeyWrite(String key, String value) {}
void passkeyRemove(String key) {}
void passkeyLock() {}
Future<Map<String, dynamic>> passkeyStatus() async =>
    {'ok': true, 'supported': false, 'enrolled': false};
Future<Map<String, dynamic>> passkeyEnroll(String data, String label) async =>
    {'ok': false, 'code': 'unsupported'};
Future<Map<String, dynamic>> passkeyUnlock() async =>
    {'ok': false, 'code': 'unsupported'};
Future<Map<String, dynamic>> passkeyRefresh(String data) async =>
    {'ok': false, 'code': 'unsupported'};
Future<Map<String, dynamic>> passkeyForget() async =>
    {'ok': false, 'code': 'unsupported'};
