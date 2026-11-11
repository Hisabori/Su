import 'api_service.dart';
import 'community_service.dart';
import 'device_history_service.dart';
import 'token_storage_service.dart';

/// Cloud observations are produced by the server, never uploaded by a client.
class DeviceCloudService {
  DeviceCloudService({CommunityService? service, TokenStorageService? tokens})
      : tokens = tokens ?? TokenStorageService(),
        service = service ?? CommunityService(tokens: tokens);
  final CommunityService service;
  final TokenStorageService tokens;
  final _rows = <String, DeviceReading>{};
  String? _scope, _cursor;
  DateTime? _loadedAt;
  Future<List<DeviceReading>?>? _pending;
  bool get hasMore => _cursor != null;

  Future<(int, String, String)?> _context() async {
    final profile = await tokens.device();
    if (profile['device_history_enabled'] != true) {
      _rows.clear();
      _cursor = null;
      _loadedAt = null;
      _scope = null;
      return null;
    }
    final user = await tokens.userId();
    if (user == null) throw ApiFailure('다시 로그인해 주세요. [DVC-001]');
    final partner = '${profile['company_device_name'] ?? ''}'.trim();
    final kiosk = '${profile['kiosk_id'] ?? ''}'.trim();
    final scope = '$user/$partner/$kiosk';
    if (_scope != scope) {
      _rows.clear();
      _cursor = null;
      _loadedAt = null;
      _scope = scope;
    }
    return (user, partner, kiosk);
  }

  DeviceReading _decode(Object? raw, (int, String, String) context) {
    if (raw is! Map ||
        raw['partner'] != context.$2 ||
        raw['kiosk'] != context.$3) {
      throw ApiFailure('서버 기기 기록의 배정 정보를 확인하지 못했습니다. [DVC-204]');
    }
    return DeviceReading.fromJson(
        {...Map<String, dynamic>.from(raw), 'user_id': context.$1});
  }

  List<DeviceReading> _snapshot() =>
      _rows.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  Future<List<DeviceReading>?> load() async {
    final context = await _context();
    if (context == null) return null;
    if (_pending != null) return _pending;
    if (_loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 15)) {
      return _snapshot();
    }
    final request = _page(context);
    _pending = request;
    try {
      return await request;
    } finally {
      _pending = null;
    }
  }

  Future<List<DeviceReading>> _page((int, String, String) context,
      {bool more = false}) async {
    final scope = _scope;
    final reply = await service.request(
        'device_history', {if (more && _cursor != null) 'cursor': _cursor});
    if (scope != _scope) throw ApiFailure('로그인 사용자가 변경되었습니다. [DVC-001]');
    if (reply['records'] is! List) {
      throw ApiFailure('서버 기록 응답을 확인하지 못했습니다. [DVC-204]');
    }
    for (final raw in reply['records'] as List) {
      final row = _decode(raw, context);
      _rows[row.at.toUtc().toIso8601String()] = row;
    }
    if (more || _loadedAt == null || _cursor == null) {
      _cursor = reply['cursor'] as String?;
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _rows.removeWhere((_, row) => row.at.isBefore(cutoff));
    _loadedAt = DateTime.now();
    return _snapshot();
  }

  Future<List<DeviceReading>?> loadMore() async {
    final context = await _context();
    if (context == null) return null;
    if (_pending != null) await _pending;
    if (_cursor == null) return _snapshot();
    final request = _page(context, more: true);
    _pending = request;
    try {
      return await request;
    } finally {
      _pending = null;
    }
  }

  Future<bool> sample() async {
    final context = await _context();
    if (context == null) return false;
    final scope = _scope;
    final reply = await service.request('device_sample');
    if (scope != _scope) throw ApiFailure('로그인 사용자가 변경되었습니다. [DVC-001]');
    final row = _decode(reply['reading'], context);
    _rows[row.at.toUtc().toIso8601String()] = row;
    return true;
  }

  void close() => service.close();
}
