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

enum CommunitySort { newest, oldest, notices }

/// Sort a copy so changing views never changes pagination's source order.
List<Map<String, dynamic>> sortCommunityPosts(
    Iterable<Map<String, dynamic>> posts, CommunitySort order) {
  final result = posts.toList();
  num? stamp(Map<String, dynamic> post) {
    final value = post['createdAt'];
    return value is num && value.isFinite && value > 0 ? value : null;
  }

  result.sort((a, b) {
    if (order == CommunitySort.notices) {
      final pinned =
          (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0);
      if (pinned != 0) return pinned;
    }
    final left = stamp(a), right = stamp(b);
    if (left == null && right != null) return 1;
    if (right == null && left != null) return -1;
    if (left != null && right != null) {
      final time = order == CommunitySort.oldest
          ? left.compareTo(right)
          : right.compareTo(left);
      if (time != 0) return time;
    }
    return '${a['id'] ?? ''}'.compareTo('${b['id'] ?? ''}');
  });
  return result;
}
