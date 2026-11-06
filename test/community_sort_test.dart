import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/utils/community_utils.dart';

void main() {
  final posts = <Map<String, dynamic>>[
    {'id': 'b', 'createdAt': 20},
    {'id': 'a', 'createdAt': 10, 'pinned': true},
    {'id': 'c', 'createdAt': 30},
    {'id': 'missing'},
  ];
  List<Object?> ids(CommunitySort order) =>
      sortCommunityPosts(posts, order).map((p) => p['id']).toList();
  test('date and notice orders keep missing dates last without mutating source',
      () {
    expect(ids(CommunitySort.newest), ['c', 'b', 'a', 'missing']);
    expect(ids(CommunitySort.oldest), ['a', 'b', 'c', 'missing']);
    expect(ids(CommunitySort.notices), ['a', 'c', 'b', 'missing']);
    expect(posts.first['id'], 'b');
  });
  test('filtered subsets sort independently and equal dates have stable IDs',
      () {
    final rows = sortCommunityPosts([
      {'id': 'z', 'createdAt': 10},
      {'id': 'a', 'createdAt': 10},
      {'id': 'invalid', 'createdAt': double.nan},
    ], CommunitySort.newest);
    expect(rows.map((p) => p['id']), ['a', 'z', 'invalid']);
    expect(
        sortCommunityPosts(
                posts.where((p) => p['pinned'] == true), CommunitySort.oldest)
            .single['id'],
        'a');
  });
}
