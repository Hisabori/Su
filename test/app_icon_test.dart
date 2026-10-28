import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/widgets/app_icon.dart';
import 'package:suho_angel/widgets/app_icon_paths.dart' show appIconPath;

void main() {
  test('all imported vectors produce finite visible geometry', () {
    for (final kind in AppIconKind.values) {
      final bounds = appIconPath(kind).getBounds();
      expect(bounds.isFinite, isTrue, reason: kind.name);
      expect(bounds.width, greaterThan(0), reason: kind.name);
      expect(bounds.height, greaterThan(0), reason: kind.name);
    }
  });
  testWidgets('custom icons paint in high contrast with reduced motion',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(highContrast: true, disableAnimations: true),
        child: const IconTheme(
            data: IconThemeData(size: 28),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(AppIconKind.collector),
              AppIcon(AppIconKind.settings),
              AppIcon(AppIconKind.community),
            ])),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppIcon).first), const Size(28, 28));
    expect(tester.takeException(), isNull);
  });
}
