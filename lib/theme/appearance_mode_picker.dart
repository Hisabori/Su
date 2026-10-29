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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '화면 테마'),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ThemeMode>(
            value: appearance.mode,
            isExpanded: true,
            isDense: true,
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('시스템')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('라이트')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('다크')),
            ],
            onChanged: appearance.saving || appearance.setMode == null
                ? null
                : (value) async {
                    if (value == null) return;
                    final saved = await appearance.setMode!(value);
                    if (!saved && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('테마 설정을 저장하지 못했습니다. 다시 시도해 주세요.')));
                    }
                  },
          ),
        ),
      ),
    );
  }
}
