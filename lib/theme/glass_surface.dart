import 'dart:ui';
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
    final opaque = MediaQuery.highContrastOf(context);
    final panel = Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: opaque
                    ? const [Colors.white, Colors.white]
                    : const [Color(0xEDFFFFFF), Color(0xCFFFFFFF)]),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: opaque ? AppStyle.muted : const Color(0xE6FFFFFF),
                width: 1.2)),
        child: child);
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: AppStyle.shadow),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: opaque
                ? panel
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: panel)));
  }
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
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                    Color(0xFFF2F7F5),
                                    Color(0xFFFAFAF7),
                                    Color(0xFFF2F7F5)
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
