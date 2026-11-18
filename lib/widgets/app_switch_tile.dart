import 'package:flutter/material.dart';
import '../theme/app_style.dart';

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile(
      {super.key,
      required this.title,
      this.subtitle,
      required this.value,
      this.onChanged});
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => AppStyle.isBeta(context)
      ? Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: SwitchListTile.adaptive(
              title: title,
              subtitle: subtitle,
              value: value,
              onChanged: onChanged))
      : SwitchListTile(
          title: title, subtitle: subtitle, value: value, onChanged: onChanged);
}
