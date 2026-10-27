import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
    BoxShadow(color: Color(0x151B3861), blurRadius: 32, offset: Offset(0, 12))
  ];
  static ThemeData theme() => ThemeData(
        extensions: const [BetaTheme()],
        useMaterial3: true,
        fontFamily: 'NanumGothic',
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder()
        }),
        cardTheme: CardThemeData(
            color: const Color(0xB3FFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xE6FFFFFF)))),
        dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xF0FFFFFF),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28))),
        bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xF0FFFFFF),
            surfaceTintColor: Colors.transparent,
            showDragHandle: true),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xE6FFFFFF),
            foregroundColor: navy,
            elevation: 5),
        colorScheme: ColorScheme.fromSeed(seedColor: navy).copyWith(
            primary: navy,
            secondary: teal,
            surface: Colors.white,
            onSurface: ink,
            outline: muted,
            outlineVariant: line),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xBFFFFFFF),
            foregroundColor: ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
                fontFamily: 'NanumGothic',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ink)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(
                    fontFamily: 'NanumGothic',
                    fontSize: 17,
                    fontWeight: FontWeight.w800))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 50),
                side: const BorderSide(color: line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0x99FFFFFF),
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
