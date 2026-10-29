import 'package:flutter/material.dart';
import '../models/work_info.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import 'app_icon.dart';

/// A focused work home: server assignment first, then frequently used tools.
class WorkHomePanel extends StatelessWidget {
  const WorkHomePanel(
      {super.key,
      required this.info,
      required this.name,
      required this.onStart,
      required this.onCollector,
      required this.onCommunity,
      required this.onHistory,
      this.waitText});
  final WorkInfo info;
  final String? name, waitText;
  final VoidCallback? onStart;
  final VoidCallback onCollector, onCommunity, onHistory;

  Widget metric(BuildContext context, String label, String value) => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppStyle.isDark(context)
                ? Color(0xFF26382F)
                : Color(0xFFF2F7F5),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppStyle.mutedOf(context))),
          SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 840),
        child:
            ListView(padding: EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
          Semantics(
              container: true,
              header: true,
              child: Text('안녕하세요!',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppStyle.inkOf(context)))),
          SizedBox(height: 8),
          Text(
              name == null || name!.trim().isEmpty
                  ? '오늘도 차근차근 함께해요.'
                  : '${name!.trim()} 님, 오늘도 차근차근 함께해요.',
              style: TextStyle(
                  fontSize: 15, height: 1.6, color: AppStyle.mutedOf(context))),
          SizedBox(height: 24),
          GlassSurface(
              padding: EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      AppIcon(AppIconKind.history, size: 24),
                      SizedBox(width: 8),
                      Text('오늘의 근무',
                          style: TextStyle(
                              color: AppStyle.mintOf(context),
                              fontWeight: FontWeight.w800))
                    ]),
                    SizedBox(height: 16),
                    Text(info.name,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.4)),
                    SizedBox(height: 18),
                    LayoutBuilder(builder: (context, bounds) {
                      final single =
                          MediaQuery.textScalerOf(context).scale(16) > 22 ||
                              bounds.maxWidth < 240;
                      final width =
                          single ? bounds.maxWidth : (bounds.maxWidth - 12) / 2;
                      final metrics = <(String, String)>[
                        if (info.startTime != null) ('시작 시간', info.startTime!),
                        if (info.endTime != null) ('종료 시간', info.endTime!),
                        if (info.workMinutes != null)
                          ('기준 작업', '${info.workMinutes}분'),
                        if (info.restMinutes != null)
                          ('기준 휴식', '${info.restMinutes}분'),
                      ];
                      return metrics.isEmpty
                          ? Text('근무 시간 정보가 없습니다.',
                              style:
                                  TextStyle(color: AppStyle.mutedOf(context)))
                          : Wrap(spacing: 12, runSpacing: 12, children: [
                              for (final item in metrics)
                                SizedBox(
                                    width: width,
                                    child: metric(context, item.$1, item.$2))
                            ]);
                    }),
                    SizedBox(height: 20),
                    if (info.steps.isEmpty)
                      Text('진행할 작업 단계가 없습니다.')
                    else
                      FilledButton(
                          onPressed: onStart,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppStyle.teal,
                              foregroundColor: Colors.white),
                          child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text('작업 시작'))),
                    if (waitText != null) ...[
                      SizedBox(height: 10),
                      Text(waitText!, textAlign: TextAlign.center)
                    ],
                    SizedBox(height: 12),
                    Text('질문은 음성으로 듣고, 버튼으로 답할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppStyle.mutedOf(context))),
                  ])),
          SizedBox(height: 26),
          Text('자주 쓰는 기능',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('필요할 때 편하게 확인해 보세요.',
              style: TextStyle(color: AppStyle.mutedOf(context), height: 1.5)),
          SizedBox(height: 14),
          LayoutBuilder(builder: (context, bounds) {
            final wide = bounds.maxWidth >= 600;
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
            final width = wide
                ? (bounds.maxWidth - 24) / 3
                : largeText
                    ? bounds.maxWidth
                    : (bounds.maxWidth - 12) / 2;
            Widget action(
                    String label, AppIconKind kind, VoidCallback callback) =>
                SizedBox(
                    width: width,
                    child: OutlinedButton(
                      onPressed: callback,
                      style: OutlinedButton.styleFrom(
                          backgroundColor: AppStyle.surfaceOf(context),
                          padding: EdgeInsets.all(18),
                          alignment: Alignment.centerLeft),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppIcon(kind, size: 34),
                            SizedBox(height: 12),
                            Text(label,
                                style: TextStyle(
                                    color: AppStyle.inkOf(context),
                                    fontWeight: FontWeight.w800))
                          ]),
                    ));
            return Wrap(spacing: 12, runSpacing: 12, children: [
              action('수거기 기록', AppIconKind.collector, onCollector),
              action('동료 이야기', AppIconKind.community, onCommunity),
              action('내 근무기록', AppIconKind.history, onHistory),
            ]);
          }),
        ]),
      ));
}
