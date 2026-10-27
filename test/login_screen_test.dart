import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/main.dart';

void main() {
  testWidgets('login screen validates empty credentials without navigation',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
    await tester.pumpWidget(const SuhoAngelApp());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('아이디와 비밀번호를 입력해 주세요.'), findsOneWidget);
  });
}
