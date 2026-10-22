import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/screens/community_detail_screen.dart';
import 'package:suho_angel/services/community_service.dart';

class FixtureCommunity extends CommunityService {
  bool liked = false;
  String? comment;
  final actions = <String>[];
  @override
  Future<Map<String, dynamic>> request(String action,
      [Map<String, dynamic> data = const {}]) async {
    actions.add(action);
    if (action == 'like') liked = data['liked'] as bool;
    if (action == 'comment_create') {
      expect(data.containsKey('author'), false);
      expect(data['commentId'], matches(RegExp(r'^\d{13}-')));
      comment = data['body'] as String;
    }
    return {
      'post': {'title': '테스트 글', 'body': '본문', 'author': '서버 작성자'},
      'comments': [
        if (comment != null)
          {'id': 'comment', 'body': comment, 'author': '서버 사용자', 'mine': true}
      ],
      'liked': liked,
      'likes': liked ? 1 : 0,
      'isAdmin': false,
    };
  }
}

void main() {
  testWidgets(
      'detail uses server identity, submits comments and explicit like state without admin controls',
      (tester) async {
    final service = FixtureCommunity();
    addTearDown(service.close);
    await tester.pumpWidget(
        MaterialApp(home: CommunityDetailScreen(service: service, id: 'post')));
    await tester.pumpAndSettle();
    expect(find.textContaining('서버 작성자'), findsOneWidget);
    expect(find.text('공지로 등록'), findsNothing);
    expect(find.text('글 숨기기'), findsNothing);
    await tester.tap(find.text('좋아요 0'));
    await tester.pumpAndSettle();
    expect(find.text('좋아요 취소 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '응원합니다.');
    await tester.ensureVisible(find.text('댓글 등록'));
    await tester.tap(find.text('댓글 등록'));
    await tester.pumpAndSettle();
    expect(find.text('응원합니다.'), findsOneWidget);
    expect(service.actions.where((a) => a == 'comment_create').length, 1);
    await tester.ensureVisible(find.text('신고하기'));
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고 접수'));
    await tester.pump();
    expect(find.text('신고 사유를 입력해 주세요.'), findsOneWidget);
    expect(service.actions.contains('report'), false);
    await tester.tap(find.text('취소'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
