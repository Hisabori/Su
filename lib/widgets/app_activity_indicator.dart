import 'package:flutter/cupertino.dart';

/// Shared iOS-style activity wheel with a static reduced-motion fallback.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator(
      {super.key, this.color, this.semanticsLabel = '불러오는 중'});
  final Color? color;
  final String semanticsLabel;
  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        child: CupertinoActivityIndicator(
          radius: 10,
          color: color,
          animating: !MediaQuery.disableAnimationsOf(context) &&
              !MediaQuery.accessibleNavigationOf(context),
        ),
      );
}
