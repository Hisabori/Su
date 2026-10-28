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

  Widget metric(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFF2F7F5),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppStyle.muted)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Semantics(
                  container: true,
                  header: true,
                  child: const Text('안녕하세요!',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppStyle.ink))),
              const SizedBox(height: 8),
              Text(
                  name == null || name!.trim().isEmpty
                      ? '오늘도 차근차근 함께해요.'
                      : '${name!.trim()} 님, 오늘도 차근차근 함께해요.',
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: AppStyle.muted)),
              const SizedBox(height: 24),
              GlassSurface(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(children: [
                          AppIcon(AppIconKind.history, size: 24),
                          SizedBox(width: 8),
                          Text('오늘의 근무',
                              style: TextStyle(
                                  color: AppStyle.teal,
                                  fontWeight: FontWeight.w800))
                        ]),
                        const SizedBox(height: 16),
                        Text(info.name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.4)),
                        const SizedBox(height: 18),
                        LayoutBuilder(builder: (context, bounds) {
                          final single =
                              MediaQuery.textScalerOf(context).scale(16) > 22 ||
                                  bounds.maxWidth < 240;
                          final width = single
                              ? bounds.maxWidth
                              : (bounds.maxWidth - 12) / 2;
                          final metrics = <(String, String)>[
                            if (info.startTime != null)
                              ('시작 시간', info.startTime!),
                            if (info.endTime != null) ('종료 시간', info.endTime!),
                            if (info.workMinutes != null)
                              ('기준 작업', '${info.workMinutes}분'),
                            if (info.restMinutes != null)
                              ('기준 휴식', '${info.restMinutes}분'),
                          ];
                          return metrics.isEmpty
                              ? const Text('근무 시간 정보가 없습니다.',
                                  style: TextStyle(color: AppStyle.muted))
                              : Wrap(spacing: 12, runSpacing: 12, children: [
                                  for (final item in metrics)
                                    SizedBox(
                                        width: width,
                                        child: metric(item.$1, item.$2))
                                ]);
                        }),
                        const SizedBox(height: 20),
                        if (info.steps.isEmpty)
                          const Text('진행할 작업 단계가 없습니다.')
                        else
                          FilledButton(
                              onPressed: onStart,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppStyle.teal,
                                  foregroundColor: Colors.white),
                              child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text('작업 시작'))),
                        if (waitText != null) ...[
                          const SizedBox(height: 10),
                          Text(waitText!, textAlign: TextAlign.center)
                        ],
                        const SizedBox(height: 12),
                        const Text('질문은 음성으로 듣고, 버튼으로 답할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: AppStyle.muted)),
                      ])),
              const SizedBox(height: 26),
              const Text('자주 쓰는 기능',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('필요할 때 편하게 확인해 보세요.',
                  style: TextStyle(color: AppStyle.muted, height: 1.5)),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, bounds) {
                final wide = bounds.maxWidth >= 600;
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final width = wide
                    ? (bounds.maxWidth - 24) / 3
                    : largeText
                        ? bounds.maxWidth
                        : (bounds.maxWidth - 12) / 2;
                Widget action(String label, AppIconKind kind,
                        VoidCallback callback) =>
                    SizedBox(
                        width: width,
                        child: OutlinedButton(
                          onPressed: callback,
                          style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xE6FFFFFF),
                              padding: const EdgeInsets.all(18),
                              alignment: Alignment.centerLeft),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppIcon(kind, size: 34),
                                const SizedBox(height: 12),
                                Text(label,
                                    style: const TextStyle(
                                        color: AppStyle.ink,
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
