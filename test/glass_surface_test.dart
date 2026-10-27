import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/theme/glass_surface.dart';

void main() {
  testWidgets('glass blur is beta-only and high contrast remains opaque',
      (tester) async {
    Widget app(ThemeData theme, {bool highContrast = false}) => MaterialApp(
        theme: theme,
        home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: const Scaffold(
                body: Center(child: GlassCard(child: Text('읽기 쉬운 카드'))))));
    await tester.pumpWidget(app(ThemeData()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Card), findsOneWidget);
    await tester.pumpWidget(app(AppStyle.theme()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pumpWidget(app(AppStyle.theme(), highContrast: true));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('읽기 쉬운 카드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('beta backdrop toggle preserves the active navigator route',
      (tester) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (context, beta, _) => MaterialApp(
            navigatorKey: key,
            theme: beta ? AppStyle.theme() : ThemeData(),
            builder: (context, child) =>
                GlassBackdrop(enabled: beta, child: child!),
            home: const Scaffold(body: Text('첫 화면')))));
    key.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('진행 중인 화면'))));
    await tester.pumpAndSettle();
    final state = key.currentState;
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(key.currentState, same(state));
    expect(find.text('진행 중인 화면'), findsOneWidget);
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(key.currentState, same(state));
    expect(find.text('진행 중인 화면'), findsOneWidget);
  });
}
