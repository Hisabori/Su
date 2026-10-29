import 'package:flutter/material.dart';
import 'liquid_page_transition.dart';
import 'appearance_scope.dart';

abstract final class AppStyle {
  static bool isBeta(BuildContext context) =>
      Theme.of(context).extension<BetaTheme>() != null;
  static bool isDark(BuildContext context) =>
      isBeta(context) && Theme.of(context).brightness == Brightness.dark;
  static Color inkOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFE8F0ED) : ink;
  static Color mutedOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFADBEB7) : muted;
  static Color lineOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF3E5149) : line;
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF1B2924) : Colors.white;
  static Color mintOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF8ED6BA) : teal;
  static Color blueOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFAACFFF) : blue;
  static Color coralOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFB294) : coral;
  static const navy = Color(0xFF202633);
  static const coral = Color(0xFFD34A22);
  static const blue = Color(0xFF0867C5);
  static const teal = Color(0xFF287B70);
  static const background = Color(0xFFF2F2F7);
  static const ink = Color(0xFF1C1C1E);
  static const muted = Color(0xFF63636E);
  static const line = Color(0xFFE5E5EA);
  static const shadow = [
    BoxShadow(color: Color(0x071C1C1E), blurRadius: 16, offset: Offset(0, 4))
  ];
  static ThemeData theme() => ThemeData(
        extensions: const [BetaTheme()],
        useMaterial3: true,
        fontFamily: 'NanumGothic',
        visualDensity: VisualDensity.standard,
        iconTheme: const IconThemeData(color: blue, size: 22),
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: blue,
                backgroundColor: const Color(0xBFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        tooltipTheme:
            const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
        snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ink,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18))),
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.iOS: LiquidPageTransitionsBuilder(),
          TargetPlatform.android: LiquidPageTransitionsBuilder(),
          TargetPlatform.macOS: LiquidPageTransitionsBuilder()
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
            primary: blue,
            secondary: teal,
            surface: Colors.white,
            onSurface: ink,
            outline: muted,
            outlineVariant: line),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xF2F2F2F7),
            foregroundColor: ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
                fontFamily: 'NanumGothic',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
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
            fillColor: const Color(0xFFF7F7FA),
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
  static ThemeData darkTheme() {
    final colors =
        ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.dark)
            .copyWith(
                primary: const Color(0xFF9AD7C2),
                onPrimary: const Color(0xFF14382D),
                secondary: const Color(0xFFAFCFFF),
                surface: const Color(0xFF1B2924),
                onSurface: const Color(0xFFE8F0ED),
                onSurfaceVariant: const Color(0xFFADBEB7),
                outlineVariant: const Color(0xFF3E5149));
    final light = theme();
    return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'NanumGothic',
        colorScheme: colors,
        extensions: const [BetaTheme()],
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: light.pageTransitionsTheme,
        appBarTheme: light.appBarTheme.copyWith(
            backgroundColor: const Color(0xF2111D18),
            foregroundColor: colors.onSurface,
            titleTextStyle: light.appBarTheme.titleTextStyle
                ?.copyWith(color: colors.onSurface)),
        iconTheme: const IconThemeData(color: Color(0xFFAFCFFF), size: 22),
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: const Color(0xFFAFCFFF),
                backgroundColor: const Color(0xD022332B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        cardTheme: light.cardTheme.copyWith(color: colors.surface),
        dialogTheme:
            light.dialogTheme.copyWith(backgroundColor: colors.surface),
        bottomSheetTheme:
            light.bottomSheetTheme.copyWith(backgroundColor: colors.surface),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer),
        filledButtonTheme: light.filledButtonTheme,
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: light.outlinedButtonTheme.style?.copyWith(
                side: WidgetStatePropertyAll(
                    BorderSide(color: colors.outlineVariant)))),
        inputDecorationTheme: light.inputDecorationTheme.copyWith(
            fillColor: const Color(0xFF26382F),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.outlineVariant)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.5))),
        tooltipTheme: light.tooltipTheme,
        snackBarTheme: light.snackBarTheme.copyWith(
            backgroundColor: const Color(0xFFDBE9E2),
            contentTextStyle: const TextStyle(color: Color(0xFF17291E))),
        progressIndicatorTheme: ProgressIndicatorThemeData(
            color: colors.primary, linearTrackColor: colors.outlineVariant),
        dividerTheme: DividerThemeData(color: colors.outlineVariant));
  }
}
