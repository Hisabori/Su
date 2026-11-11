import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import '../utils/device_summary.dart';
import 'app_icon.dart';

class DeviceSummaryCard extends StatelessWidget {
  const DeviceSummaryCard(
      {super.key, required this.summary, required this.week});
  final DevicePeriodSummary summary;
  final bool week;
  @override
  Widget build(BuildContext context) => GlassCard(
      semanticContainer: false,
      child: Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const AppIcon(AppIconKind.chart, size: 24),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(week ? '최근 7일 한눈에' : '오늘 한눈에',
                      style: TextStyle(
                          color: AppStyle.inkOf(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, bounds) {
              final single = bounds.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22;
              final width =
                  single ? bounds.maxWidth : (bounds.maxWidth - 12) / 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final metric in [
                  ('측정 평균', DevicePeriodSummary.percent(summary.average)),
                  ('최고 적재율', DevicePeriodSummary.percent(summary.maximum)),
                ])
                  Container(
                      width: width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color:
                              AppStyle.mintOf(context).withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.$1,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyle.mutedOf(context))),
                            const SizedBox(height: 8),
                            Text(metric.$2,
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppStyle.mintOf(context))),
                          ])),
              ]);
            }),
            const SizedBox(height: 14),
            Text('유효 측정 ${summary.valid}회 · 미확인 ${summary.unknown}회',
                style:
                    TextStyle(color: AppStyle.mutedOf(context), height: 1.6)),
            const SizedBox(height: 6),
            Text('현재 불러온 측정값의 평균입니다. 앱이 닫힌 동안의 상태와 미확인 값은 포함하지 않습니다.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppStyle.mutedOf(context),
                    height: 1.6)),
          ])));
}
