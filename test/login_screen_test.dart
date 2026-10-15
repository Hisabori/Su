import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/main.dart';

void main() {
  testWidgets('login screen validates empty credentials without navigation',
      (tester) async {
    await tester.pumpWidget(const SuhoAngelApp());
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('아이디와 비밀번호를 입력해 주세요.'), findsOneWidget);
  });
}
