import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/app_preferences.dart';
import 'theme/app_style.dart';
import 'theme/glass_surface.dart';
import 'theme/appearance_scope.dart';

void main() => runApp(const SuhoAngelApp());

class SuhoAngelApp extends StatefulWidget {
  const SuhoAngelApp({super.key});
  @override
  State<SuhoAngelApp> createState() => _SuhoAngelAppState();
}

class _SuhoAngelAppState extends State<SuhoAngelApp> {
  final preferences = AppPreferences();
  bool beta = true, saving = false, restoring = true;
  ThemeMode mode = ThemeMode.system;
  @override
  void initState() {
    super.initState();
    restoreAppearance();
  }

  Future<void> restoreAppearance() async {
    final enabled = await preferences.betaEnabled();
    final selectedMode = ThemeMode.values.byName(await preferences.colorMode());
    if (mounted) {
      setState(() {
        beta = enabled;
        mode = selectedMode;
        restoring = false;
      });
    }
  }

  Future<bool> setBeta(bool enabled) async {
    if (saving || restoring) return false;
    setState(() => saving = true);
    try {
      await preferences.setBetaEnabled(enabled);
      if (!mounted) return false;
      setState(() => beta = enabled);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> setMode(ThemeMode next) async {
    if (saving || restoring) return false;
    setState(() => saving = true);
    try {
      await preferences.setColorMode(next.name);
      if (!mounted) return false;
      setState(() => mode = next);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
      enabled: beta,
      saving: saving || restoring,
      setEnabled: setBeta,
      mode: mode,
      setMode: setMode,
      child: MaterialApp(
        title: '수호천사',
        debugShowCheckedModeBanner: false,
        darkTheme: AppStyle.darkTheme(),
        themeMode: beta ? mode : ThemeMode.light,
        theme: beta
            ? AppStyle.theme()
            : ThemeData(
                useMaterial3: true,
                fontFamily: 'NanumGothic',
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF00C896)),
                inputDecorationTheme:
                    const InputDecorationTheme(border: OutlineInputBorder()),
              ),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: GlassBackdrop(
                enabled: beta, child: child ?? const SizedBox.shrink())),
        home: const LoginScreen(),
      ));
}
