import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import 'app_icon.dart';

/// One accessible action, with a quiet press response and a helpful preview.
class FeatureCard extends StatefulWidget {
  const FeatureCard(
      {super.key,
      required this.label,
      required this.description,
      required this.kind,
      required this.onTap});
  final String label, description;
  final AppIconKind kind;
  final VoidCallback onTap;
  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool pressed = false, focused = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations || media.accessibleNavigation;
    final accent = media.highContrast
        ? AppStyle.inkOf(context)
        : switch (widget.kind) {
            AppIconKind.community => AppStyle.isDark(context)
                ? const Color(0xFFE0B9D4)
                : const Color(0xFF96587F),
            AppIconKind.history => AppStyle.blueOf(context),
            _ => AppStyle.mintOf(context),
          };
    final highlighted = focused || hovered;
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.description,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: pressed && !reduced ? .98 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Material(
          color: AppStyle.surfaceOf(context),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                  color: highlighted || media.highContrast
                      ? accent
                      : AppStyle.lineOf(context),
                  width: highlighted ? 2 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => pressed = true),
            onTapUp: (_) => setState(() => pressed = false),
            onTapCancel: () => setState(() => pressed = false),
            onFocusChange: (value) => setState(() => focused = value),
            onHover: (value) => setState(() => hovered = value),
            child: Ink(
              decoration: BoxDecoration(
                  gradient: media.highContrast
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                              Color.alphaBlend(accent.withValues(alpha: .11),
                                  AppStyle.surfaceOf(context)),
                              AppStyle.surfaceOf(context),
                            ])),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppIcon(widget.kind, size: 38),
                        const Spacer(),
                        Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: .09),
                                shape: BoxShape.circle),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 16, color: accent)),
                      ]),
                      const SizedBox(height: 16),
                      Text(widget.label,
                          style: TextStyle(
                              fontSize: 17,
                              color: AppStyle.inkOf(context),
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      Text(widget.description,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppStyle.mutedOf(context))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
