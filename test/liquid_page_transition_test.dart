import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/liquid_page_transition.dart';

void main() {
  testWidgets('route motion respects reduced motion and accessible navigation',
      (tester) async {
    for (final mode in [0, 1, 2]) {
      final reduced = mode != 0;
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(
                disableAnimations: mode == 1, accessibleNavigation: mode == 2),
            child: Builder(
                builder: (context) =>
                    const LiquidPageTransitionsBuilder().buildTransitions<void>(
                      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                      context,
                      const AlwaysStoppedAnimation(.5),
                      const AlwaysStoppedAnimation(0),
                      const Text('화면 전환'),
                    )),
          )));
      expect(find.byType(SlideTransition),
          reduced ? findsNothing : findsOneWidget);
      expect(find.text('화면 전환'), findsOneWidget);
    }
  });
}
