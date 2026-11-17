import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/app_activity_indicator.dart';

void main() {
  testWidgets('activity wheel respects reduced motion and announces loading',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    for (final reduced in [false, true]) {
      await tester.pumpWidget(CupertinoApp(
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const AppActivityIndicator(semanticsLabel: '기기 조회 중'))));
      await tester.pump();
      expect(
          tester
              .widget<CupertinoActivityIndicator>(
                  find.byType(CupertinoActivityIndicator))
              .animating,
          !reduced);
      expect(find.bySemanticsLabel('기기 조회 중'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
