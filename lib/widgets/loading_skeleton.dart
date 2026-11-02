import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';

enum SkeletonLayout { work, graph, list, detail }

/// Content-shaped placeholders. A single soft reveal avoids a perpetual ticker.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton(
      {super.key,
      required this.label,
      this.layout = SkeletonLayout.list,
      this.scrollable = true});
  final String label;
  final SkeletonLayout layout;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations || media.accessibleNavigation;
    final color = AppStyle.inkOf(context)
        .withValues(alpha: media.highContrast ? .22 : .09);
    Widget bar(double width, {double height = 14}) => FractionallySizedBox(
        widthFactor: width,
        alignment: Alignment.centerLeft,
        child: Container(
            height: height,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10))));
    Widget card({bool graph = false}) => GlassSurface(
        radius: 24,
        padding: const EdgeInsets.all(22),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (layout == SkeletonLayout.list ||
              layout == SkeletonLayout.detail) ...[
            Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(13))),
              const SizedBox(width: 12),
              Expanded(child: bar(.5, height: 12)),
            ]),
            const SizedBox(height: 20),
          ],
          bar(.36, height: 18),
          const SizedBox(height: 18),
          bar(.65, height: graph ? 36 : 24),
          const SizedBox(height: 12),
          bar(.9),
          const SizedBox(height: 10),
          bar(.55),
          if (layout == SkeletonLayout.detail) ...[
            const SizedBox(height: 24),
            bar(1),
            const SizedBox(height: 10),
            bar(.9),
            const SizedBox(height: 10),
            bar(.72),
          ],
          if (graph) ...[
            const SizedBox(height: 24),
            Container(
                height: 160,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(16))),
          ],
          if (layout == SkeletonLayout.work) ...[
            const SizedBox(height: 24),
            bar(1, height: 54),
          ],
        ]));
    final placeholders = TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : .45, end: 1),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          card(graph: layout == SkeletonLayout.graph),
          const SizedBox(height: 16),
          card(),
        ]));
    final content = Semantics(
        container: true,
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppStyle.mintOf(context).withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(18)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: AppStyle.mintOf(context),
                        shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Flexible(
                    child: Text(label,
                        style: TextStyle(
                            color: AppStyle.inkOf(context),
                            fontSize: 13,
                            height: 1.6))),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          placeholders,
        ]));
    if (!scrollable) return content;
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
                padding: const EdgeInsets.all(22), children: [content])));
  }
}
