import 'package:flutter/material.dart';
import 'appearance_scope.dart';
import 'app_style.dart';

class AppearanceModePicker extends StatelessWidget {
  const AppearanceModePicker({super.key});
  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceScope.of(context);
    if (appearance == null || !AppStyle.isBeta(context)) {
      return const SizedBox.shrink();
    }
    Future<void> choose(ThemeMode value) async {
      final saved = await appearance.setMode!(value);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('테마 설정을 저장하지 못했습니다. 다시 시도해 주세요.')));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('화면 테마',
            style: TextStyle(fontSize: 12, color: AppStyle.mutedOf(context))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in const [
            (ThemeMode.system, '시스템'),
            (ThemeMode.light, '라이트'),
            (ThemeMode.dark, '다크')
          ])
            ChoiceChip(
                label: Text(item.$2),
                selected: appearance.mode == item.$1,
                onSelected: appearance.saving || appearance.setMode == null
                    ? null
                    : (selected) {
                        if (selected) choose(item.$1);
                      }),
        ]),
      ]),
    );
  }
}
