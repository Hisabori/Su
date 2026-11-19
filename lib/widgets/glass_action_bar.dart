import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import 'app_icon.dart';

/// Route shortcuts, rather than tabs that imply a selected destination.
class GlassActionBar extends StatelessWidget {
  const GlassActionBar({super.key, required this.actions});
  final List<({String label, AppIconKind icon, VoidCallback? onPressed})>
      actions;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassSurface(
                radius: 34,
                padding: const EdgeInsets.all(5),
                child: Row(children: [
                  for (final action in actions)
                    Expanded(
                        child: Semantics(
                      button: true,
                      enabled: action.onPressed != null,
                      label: action.label,
                      onTap: action.onPressed,
                      excludeSemantics: true,
                      child: TextButton(
                          onPressed: action.onPressed,
                          style: TextButton.styleFrom(
                              minimumSize: const Size(48, 58),
                              foregroundColor: AppStyle.inkOf(context),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                              shape: const StadiumBorder()),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            AppIcon(action.icon, size: 24),
                            const SizedBox(height: 5),
                            Text(action.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700)),
                          ])),
                    )),
                ])),
          )));
}
