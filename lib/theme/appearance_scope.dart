import 'package:flutter/material.dart';

class AppearanceScope extends InheritedWidget {
  const AppearanceScope(
      {super.key,
      required this.enabled,
      required this.saving,
      required this.setEnabled,
      required super.child});
  final bool enabled, saving;
  final Future<bool> Function(bool) setEnabled;
  static AppearanceScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
  @override
  bool updateShouldNotify(AppearanceScope oldWidget) =>
      enabled != oldWidget.enabled || saving != oldWidget.saving;
}

class BetaTheme extends ThemeExtension<BetaTheme> {
  const BetaTheme();
  @override
  BetaTheme copyWith() => this;
  @override
  BetaTheme lerp(covariant BetaTheme? other, double t) => this;
}
