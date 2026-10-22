import 'dart:math';

String newCommunityId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().millisecondsSinceEpoch}-${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String communityStamp(Object? value) {
  if (value is! num || value <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
  return '${d.month}.${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
