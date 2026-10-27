import 'package:flutter/material.dart';

/// Gentle route motion; respects the device's reduced-motion settings.
class LiquidPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) return child;
    final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: eased,
        child: SlideTransition(
            position: eased
                .drive(Tween(begin: const Offset(.035, 0), end: Offset.zero)),
            child: child));
  }
}
