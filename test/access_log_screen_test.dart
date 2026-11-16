import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/screens/access_log_screen.dart';
import 'package:suho_angel/services/access_service.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/theme/glass_surface.dart';
import 'package:suho_angel/widgets/loading_skeleton.dart';

class PendingAccess extends AccessService {
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<Map<String, dynamic>> list({String? cursor}) => pending.future;
}

void main() {
  testWidgets(
      'glass access list shows initial and append skeletons without losing rows',
      (tester) async {
    final service = PendingAccess();
    await tester.pumpWidget(MaterialApp(
        theme: AppStyle.theme(), home: AccessLogScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byType(LoadingSkeleton), findsOneWidget);
    service.pending.complete({
      'records': [
        {
          'event_id': 'first',
          'user_id': 31,
          'name': '첫 사용자',
          'at': DateTime.now().toIso8601String()
        }
      ],
      'cursor': 'older'
    });
    await tester.pumpAndSettle();
    expect(find.text('첫 사용자 · ID 31'), findsOneWidget);
    expect(find.byType(GlassSurface), findsAtLeastNWidgets(2));
    service.pending = Completer();
    await tester.ensureVisible(find.text('이전 접속 기록 불러오기'));
    await tester.tap(find.text('이전 접속 기록 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('첫 사용자 · ID 31'), findsOneWidget);
    expect(tester.widget<LoadingSkeleton>(find.byType(LoadingSkeleton)).compact,
        isTrue);
    service.pending.complete({
      'records': [
        {
          'event_id': 'second',
          'user_id': 42,
          'name': '다른 사용자',
          'at': DateTime.now().toIso8601String()
        }
      ],
      'cursor': null
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('다른 사용자 · ID 42'));
    expect(find.text('첫 사용자 · ID 31'), findsOneWidget);
    expect(find.byType(LoadingSkeleton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
