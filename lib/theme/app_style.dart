import 'package:flutter/material.dart';
import 'appearance_scope.dart';

abstract final class AppStyle {
  static bool isBeta(BuildContext context) =>
      Theme.of(context).extension<BetaTheme>() != null;
  static const navy = Color(0xFF173B63);
  static const teal = Color(0xFF23877F);
  static const background = Color(0xFFF5F8FA);
  static const ink = Color(0xFF233447);
  static const muted = Color(0xFF697A8A);
  static const line = Color(0xFFE1E9EF);
  static const shadow = [
    BoxShadow(color: Color(0x0D173B63), blurRadius: 28, offset: Offset(0, 10))
  ];
  static ThemeData theme() => ThemeData(
        extensions: const [BetaTheme()],
        useMaterial3: true,
        fontFamily: 'NanumGothic',
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: navy).copyWith(
            primary: navy,
            secondary: teal,
            surface: Colors.white,
            onSurface: ink,
            outline: muted,
            outlineVariant: line),
        appBarTheme: const AppBarTheme(
            backgroundColor: background,
            foregroundColor: ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
                fontFamily: 'NanumGothic',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ink)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(
                    fontFamily: 'NanumGothic',
                    fontSize: 17,
                    fontWeight: FontWeight.w800))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 50),
                side: const BorderSide(color: line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: teal, width: 1.5))),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: teal, linearTrackColor: line),
        dividerTheme: const DividerThemeData(color: line),
      );
}
