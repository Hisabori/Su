import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/theme/liquid_page_transition.dart';

void main() {
  testWidgets('route motion respects reduced motion and accessible navigation',
      (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
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
