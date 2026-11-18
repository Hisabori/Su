import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_style.dart';

/// Small, clipped frosted panels; high contrast uses an opaque surface.
class GlassSurface extends StatelessWidget {
  const GlassSurface(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.width,
      this.radius = 28});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final opaque = MediaQuery.highContrastOf(context);
    final panel = Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: opaque
                    ? [AppStyle.surfaceOf(context), AppStyle.surfaceOf(context)]
                    : dark
                        ? const [
                            Color(0xE638383C),
                            Color(0xD21C1C1E),
                            Color(0xDB242428)
                          ]
                        : const [
                            Color(0xEFFFFFFF),
                            Color(0xCFFFFFFF),
                            Color(0xDBF4FAF8)
                          ]),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: opaque
                    ? AppStyle.mutedOf(context)
                    : dark
                        ? const Color(0x4D9CBFAF)
                        : const Color(0xE6FFFFFF),
                width: opaque ? 1.2 : .6)),
        child: child);
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: opaque
                ? const []
                : [
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: dark ? .18 : .045),
                        blurRadius: 26,
                        offset: const Offset(0, 10)),
                    BoxShadow(
                        color: (dark ? const Color(0xFF9DDCC6) : Colors.white)
                            .withValues(alpha: dark ? .025 : .6),
                        blurRadius: 1,
                        offset: const Offset(0, -1)),
                  ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: opaque
                ? panel
                : BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp),
                    child: CustomPaint(
                        foregroundPainter:
                            _GlassReflection(radius: radius, dark: dark),
                        child: panel))));
  }
}

/// Static highlights move naturally with the surface as the page scrolls.
/// Painted above the fill without adding a hit target or semantic element.
class _GlassReflection extends CustomPainter {
  const _GlassReflection({required this.radius, required this.dark});
  final double radius;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(.75);
    final curve = math.max(0.0, radius - .75);
    final rim = RRect.fromRectAndRadius(rect, Radius.circular(curve));
    canvas.drawRRect(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, .32, .55, .78, 1],
            colors: [
              Colors.white.withValues(alpha: dark ? .42 : .95),
              Colors.white.withValues(alpha: dark ? .06 : .18),
              Colors.white.withValues(alpha: 0),
              const Color(0xFFBCE5DB).withValues(alpha: dark ? .15 : .3),
              Colors.white.withValues(alpha: dark ? .24 : .75),
            ],
          ).createShader(rect));
    canvas.save();
    canvas.clipRRect(rim);
    final sheen = Rect.fromLTWH(0, 0, size.width, math.min(size.height, 56));
    canvas.drawRect(
        sheen,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? .05 : .13),
              Colors.white.withValues(alpha: 0)
            ],
          ).createShader(sheen));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassReflection oldDelegate) =>
      radius != oldDelegate.radius || dark != oldDelegate.dark;
}

class BetaGlass extends StatelessWidget {
  const BetaGlass({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      AppStyle.isBeta(context) ? GlassSurface(child: child) : child;
}

class GlassCard extends StatelessWidget {
  const GlassCard(
      {super.key,
      required this.child,
      this.margin,
      this.semanticContainer = true,
      this.color,
      this.shape});
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final bool semanticContainer;
  final Color? color;
  final ShapeBorder? shape;
  @override
  Widget build(BuildContext context) => AppStyle.isBeta(context)
      ? Padding(
          padding: margin ?? const EdgeInsets.all(4),
          child: Semantics(
              container: semanticContainer,
              explicitChildNodes: !semanticContainer,
              child: GlassSurface(radius: 24, child: child)))
      : Card(
          margin: margin,
          color: color,
          shape: shape,
          semanticContainer: semanticContainer,
          child: child);
}

class GlassBox extends StatelessWidget {
  const GlassBox(
      {super.key,
      required this.child,
      this.margin,
      this.padding,
      this.width,
      this.height,
      this.decoration});
  final Widget child;
  final EdgeInsetsGeometry? margin, padding;
  final double? width, height;
  final BoxDecoration? decoration;
  @override
  Widget build(BuildContext context) => AppStyle.isBeta(context)
      ? Padding(
          padding: margin ?? EdgeInsets.zero,
          child: SizedBox(
              width: width,
              height: height,
              child: GlassSurface(
                  padding: padding ?? EdgeInsets.zero, child: child)))
      : Container(
          margin: margin,
          padding: padding,
          width: width,
          height: height,
          decoration: decoration,
          child: child);
}

/// Keep the Navigator in the same slot while toggling beta to preserve work.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Positioned.fill(
            child: IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppStyle.isDark(context)
                                    ? const [
                                        Color(0xFF101012),
                                        Color(0xFF19191D),
                                        Color(0xFF14141A)
                                      ]
                                    : const [
                                        Color(0xFFF2F2F7),
                                        Color(0xFFFAFAFC),
                                        Color(0xFFF2F2F7)
                                      ])
                            : null)))),
        Positioned.fill(
            child: IgnorePointer(
                child: enabled
                    ? const Stack(children: [
                        Positioned(
                            top: -110,
                            right: -85,
                            child: _Glow(color: Color(0x33F7B59E), size: 340)),
                        Positioned(
                            bottom: -100,
                            left: -120,
                            child: _Glow(color: Color(0x33AEC8EA), size: 390)),
                      ])
                    : const SizedBox.shrink())),
        child,
      ]);
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              RadialGradient(colors: [color, color.withValues(alpha: 0)])));
}
