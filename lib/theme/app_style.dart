import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'appearance_scope.dart';

abstract final class AppStyle {
  static bool isBeta(BuildContext context) =>
      Theme.of(context).extension<BetaTheme>() != null;
  static const navy = Color(0xFF254A52);
  static const teal = Color(0xFF287B70);
  static const background = Color(0xFFF5F8FA);
  static const ink = Color(0xFF233447);
  static const muted = Color(0xFF647574);
  static const line = Color(0xFFDCE7E1);
  static const shadow = [
    BoxShadow(color: Color(0x102A5149), blurRadius: 28, offset: Offset(0, 10))
  ];
  static ThemeData theme() => ThemeData(
        extensions: const [BetaTheme()],
        useMaterial3: true,
        fontFamily: 'NanumGothic',
        visualDensity: VisualDensity.standard,
        tooltipTheme:
            const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
        snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ink,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18))),
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
