import 'package:flutter/material.dart';

class AppearanceScope extends InheritedWidget {
  const AppearanceScope(
      {super.key,
      required this.enabled,
      required this.saving,
      required this.setEnabled,
      this.mode = ThemeMode.system,
      this.setMode,
      required super.child});
  final bool enabled, saving;
  final ThemeMode mode;
  final Future<bool> Function(ThemeMode)? setMode;
  final Future<bool> Function(bool) setEnabled;
  static AppearanceScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
  @override
  bool updateShouldNotify(AppearanceScope oldWidget) =>
      enabled != oldWidget.enabled ||
      saving != oldWidget.saving ||
      mode != oldWidget.mode;
}

class BetaTheme extends ThemeExtension<BetaTheme> {
  const BetaTheme();
  @override
  BetaTheme copyWith() => this;
  @override
  BetaTheme lerp(covariant BetaTheme? other, double t) => this;
}
