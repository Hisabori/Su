import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/main.dart';
import 'package:suho_angel/screens/login_screen.dart';
import 'package:suho_angel/theme/app_style.dart';
import 'package:suho_angel/theme/appearance_scope.dart';
import 'package:suho_angel/theme/glass_surface.dart';

void main() {
  testWidgets(
      'theme changes persist without replacing navigator; legacy stays light',
      (tester) async {
    final saved = <String, String>{};
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      if (call.method == 'read') return saved[args['key']];
      if (call.method == 'write') {
        saved[args['key'] as String] = args['value'] as String;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const SuhoAngelApp());
    await tester.pumpAndSettle();
    BuildContext context() => tester.element(find.byType(LoginScreen));
    final navigator = Navigator.of(context());
    expect(
        await AppearanceScope.of(context())!.setMode!(ThemeMode.dark), isTrue);
    await tester.pumpAndSettle();
    expect(Theme.of(context()).brightness, Brightness.dark);
    expect(saved['suho_pref_color_mode'], 'dark');
    expect(Navigator.of(context()), same(navigator));
    await AppearanceScope.of(context())!.setEnabled(false);
    await tester.pumpAndSettle();
    expect(Theme.of(context()).brightness, Brightness.light);
    await AppearanceScope.of(context())!.setEnabled(true);
    await tester.pumpAndSettle();
    expect(Theme.of(context()).brightness, Brightness.dark);
    expect(Navigator.of(context()), same(navigator));
    expect(tester.takeException(), isNull);
  });
  testWidgets('system dark mode and high contrast keep readable opaque panels',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: AppStyle.theme(),
      darkTheme: AppStyle.darkTheme(),
      themeMode: ThemeMode.system,
      home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: Scaffold(
              body: Builder(
                  builder: (context) => GlassSurface(
                      child: Text('다크 카드',
                          style: TextStyle(color: AppStyle.inkOf(context))))))),
    ));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('다크 카드'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(AppStyle.inkOf(context).computeLuminance(), greaterThan(.7));
    expect(AppStyle.surfaceOf(context).computeLuminance(), lessThan(.1));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
