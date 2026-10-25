import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/community_draft_service.dart';
import 'storage_submission_test.dart' show MemoryStore;

void main() {
  test(
      'draft text survives reopening, is account isolated and cleared in write order',
      () async {
    final store = MemoryStore();
    final drafts = CommunityDraftService(store: store);
    await drafts.save(31, '제목', '내용');
    expect(await CommunityDraftService(store: store).load(31),
        {'title': '제목', 'body': '내용'});
    expect(await drafts.load(42), isNull);
    await Future.wait(
        [drafts.save(31, '이전', '이전'), drafts.save(31, '최신', '최신')]);
    expect((await drafts.load(31))!['title'], '최신');
    await Future.wait([drafts.save(31, '저장 중', '본문'), drafts.clear(31)]);
    expect(await drafts.load(31), isNull);
  });
}
