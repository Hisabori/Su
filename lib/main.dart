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
  bool beta = false, saving = false, restoring = true;
  @override
  void initState() {
    super.initState();
    restoreAppearance();
  }

  Future<void> restoreAppearance() async {
    final enabled = await preferences.betaEnabled();
    if (mounted) {
      setState(() {
        beta = enabled;
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

  @override
  Widget build(BuildContext context) => AppearanceScope(
      enabled: beta,
      saving: saving || restoring,
      setEnabled: setBeta,
      child: MaterialApp(
        title: '수호천사',
        debugShowCheckedModeBanner: false,
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
        builder: (context, child) => GlassBackdrop(
            enabled: beta, child: child ?? const SizedBox.shrink()),
        home: const LoginScreen(),
      ));
}
