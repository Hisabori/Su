import '../widgets/app_icon.dart';
import '../theme/glass_surface.dart';
import '../theme/app_style.dart';
import 'package:flutter/material.dart';
import '../services/device_history_service.dart';
import '../widgets/device_history_chart.dart';

class DeviceHistoryScreen extends StatefulWidget {
  const DeviceHistoryScreen(
      {super.key,
      required this.monitor,
      required this.userId,
      required this.partner,
      required this.kiosk,
      required this.onRefresh});
  final DeviceMonitor monitor;
  final int userId;
  final String partner, kiosk;
  final Future<void> Function() onRefresh;
  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  List<DeviceReading> records = [];
  bool loading = true, week = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.monitor.addListener(changed);
    load();
  }

  @override
  void dispose() {
    widget.monitor.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final data = await widget.monitor.history
          .load(widget.userId, widget.partner, widget.kiosk);
      if (mounted && request == generation) {
        setState(() {
          records = data;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = '기기 기록을 불러오지 못했습니다.');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  String time(DateTime value) {
    final t = value.toLocal();
    return '${t.month}월 ${t.day}일 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = records
        .where((r) =>
            week ||
            r.at.toLocal().year == now.year &&
                r.at.toLocal().month == now.month &&
                r.at.toLocal().day == now.day)
        .toList();
    final latest = records.isEmpty ? null : records.last;
    return Scaffold(
        appBar: AppBar(title: const Text('수거기 적재율 기록'), actions: [
          IconButton(
              tooltip: '지금 기기 조회',
              onPressed: widget.monitor.fetching ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh))
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(padding: const EdgeInsets.all(22), children: [
                  Text(latest?.name ?? '배정된 기기',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('페트병 수거기 · 10분마다 적재율 조회',
                      style: TextStyle(height: 1.6)),
                  const SizedBox(height: 16),
                  Row(children: [
                    ChoiceChip(
                        label: const Text('오늘'),
                        selected: !week,
                        onSelected: (_) => setState(() => week = false)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                        label: const Text('7일'),
                        selected: week,
                        onSelected: (_) => setState(() => week = true))
                  ]),
                  const SizedBox(height: 18),
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (error != null) Text(error!),
                  GlassCard(
                      semanticContainer: false,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (AppStyle.isBeta(context)) ...[
                                  const Row(children: [
                                    AppIcon(AppIconKind.chart, size: 20),
                                    SizedBox(width: 6),
                                    Text('적재율 추이',
                                        style: TextStyle(
                                            color: AppStyle.coral,
                                            fontWeight: FontWeight.w800))
                                  ]),
                                  const SizedBox(height: 10),
                                  Text(latest?.percentLabel ?? '측정 전',
                                      style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          color: AppStyle.ink)),
                                  Text(
                                      latest == null
                                          ? '조회 후 그래프가 표시됩니다.'
                                          : '마지막 조회 · ${time(latest.at)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppStyle.muted)),
                                  const SizedBox(height: 12),
                                ],
                                DeviceHistoryChart(records: visible),
                              ]))),
                  const SizedBox(height: 16),
                  if (latest != null)
                    GlassCard(
                        semanticContainer: false,
                        child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('마지막 적재율'),
                                  const SizedBox(height: 8),
                                  Text(latest.percentLabel,
                                      style: TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                  Text(time(latest.at)),
                                  if (now.difference(latest.at) >
                                      const Duration(minutes: 15))
                                    const Text('갱신이 지연되고 있습니다. 지금 조회해 주세요.'),
                                  if (latest.available == false)
                                    const Text('기기 사용 불가'),
                                  if (latest.error != null) Text(latest.error!),
                                ]))),
                  if (widget.monitor.storageFailed)
                    const Text('현재 조회 결과를 기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요.'),
                  const SizedBox(height: 20),
                  const Text(
                      '앱이 열려 있을 때 10분마다 조회합니다. 최근 7일 기록을 이 기기에 저장하며, 중단된 구간과 미확인 값은 연결하지 않습니다.',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  const SizedBox(height: 16),
                  Text('조회 기록 ${visible.length}회',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final reading in visible.reversed)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(time(reading.at)),
                                    Text(
                                        reading.error ??
                                            (reading.current == null ||
                                                    reading.capacity == null
                                                ? '용량 정보 없음'
                                                : '${reading.current} / ${reading.capacity}'),
                                        style: const TextStyle(fontSize: 12))
                                  ])),
                              Text(reading.percentLabel,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                            ])),
                  if (!loading && visible.isEmpty)
                    const Text('조회 기록이 없습니다. 오른쪽 위 버튼으로 지금 확인할 수 있습니다.'),
                ]))));
  }
}
