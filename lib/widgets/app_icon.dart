import 'package:flutter/material.dart';
import 'app_icon_paths.dart';
export 'app_icon_paths.dart' show AppIconKind;

/// Locally bundled Lucide vectors, customized with tinted tiles and micro-motion.
class AppIcon extends StatefulWidget {
  const AppIcon(this.kind, {super.key, this.size});
  final AppIconKind kind;
  final double? size;
  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  bool hover = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations || media.accessibleNavigation;
    final size = widget.size ?? IconTheme.of(context).size ?? 24;
    return ExcludeSemantics(
        child: MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => pressed = true),
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: TweenAnimationBuilder<double>(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          tween: Tween(
              begin: 0,
              end: reduced
                  ? 0
                  : pressed
                      ? -.6
                      : hover
                          ? 1
                          : 0),
          builder: (context, value, child) => Transform.rotate(
              angle: value * .06,
              child: Transform.scale(scale: 1 + value * .07, child: child)),
          child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                  painter: _IconPainter(widget.kind, media.highContrast,
                      Theme.of(context).brightness == Brightness.dark))),
        ),
      ),
    ));
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.highContrast, this.dark);
  final AppIconKind kind;
  final bool highContrast, dark;
  static const colors = <Color>[
    Color(0xFF5265B8),
    Color(0xFF207767),
    Color(0xFF9C4785),
    Color(0xFF426BA5),
    Color(0xFF91651E),
    Color(0xFFC44F2C),
    Color(0xFF6753A6),
    Color(0xFF357A9A),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final color = highContrast
        ? Colors.black
        : dark
            ? Color.lerp(colors[kind.index], Colors.white, .45)!
            : colors[kind.index];
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 24, 24), const Radius.circular(7)),
        Paint()
          ..color = highContrast ? Colors.white : color.withValues(alpha: .11));
    canvas.translate(3, 3);
    canvas.scale(.75);
    canvas.drawPath(
        appIconPath(kind),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = highContrast ? 2.4 : 1.9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.kind != kind || old.highContrast != highContrast || old.dark != dark;
}
