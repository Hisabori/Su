import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/device_history_service.dart';
import '../theme/app_style.dart';

class DeviceHistoryChart extends StatefulWidget {
  const DeviceHistoryChart({super.key, required this.records});
  final List<DeviceReading> records;
  @override
  State<DeviceHistoryChart> createState() => _DeviceHistoryChartState();
}

class _DeviceHistoryChartState extends State<DeviceHistoryChart> {
  DeviceReading? selected;
  List<DeviceReading> get records => widget.records;
  @override
  void didUpdateWidget(DeviceHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected != null && !records.contains(selected)) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final valid = records.where((r) => r.percent != null).length;
    return Semantics(
        container: true,
        image: true,
        label:
            '페트병 수거기 적재율 추이 그래프. 유효한 측정 $valid회. 실선은 측정값 연결, 점선은 조회 공백입니다. 자세한 수치는 아래 기록에서 확인할 수 있습니다.',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: records.isEmpty
                        ? null
                        : (details) {
                            final ordered = List<DeviceReading>.of(records)
                              ..sort((a, b) => a.at.compareTo(b.at));
                            final width =
                                math.max(1.0, constraints.maxWidth - 56);
                            final fraction =
                                ((details.localPosition.dx - 44) / width)
                                    .clamp(0.0, 1.0);
                            final target =
                                ordered.first.at.millisecondsSinceEpoch +
                                    fraction *
                                        ordered.last.at
                                            .difference(ordered.first.at)
                                            .inMilliseconds;
                            final nearest = ordered.reduce((a, b) =>
                                (a.at.millisecondsSinceEpoch - target).abs() <=
                                        (b.at.millisecondsSinceEpoch - target)
                                            .abs()
                                    ? a
                                    : b);
                            setState(() => selected = nearest);
                          },
                    child: SizedBox(
                        width: double.infinity,
                        height: 240,
                        child: CustomPaint(
                            painter: _Chart(
                                records,
                                AppStyle.isBeta(context)
                                    ? AppStyle.coralOf(context)
                                    : Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.onSurface))),
                  )),
          if (records.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                    liveRegion: selected != null,
                    child: Text(
                        selected == null
                            ? '그래프를 누르면 해당 시각의 측정값을 확인할 수 있어요.'
                            : '${selected!.at.toLocal().month}/${selected!.at.toLocal().day} ${selected!.at.toLocal().hour.toString().padLeft(2, '0')}:${selected!.at.toLocal().minute.toString().padLeft(2, '0')} · ${selected!.percentLabel}',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppStyle.mutedOf(context))))),
        ]));
  }
}

class _Chart extends CustomPainter {
  _Chart(List<DeviceReading> records, this.color, this.ink)
      : records = List.of(records)..sort((a, b) => a.at.compareTo(b.at));
  final List<DeviceReading> records;
  final Color color, ink;
  double canvasWidth = 240;
  void label(Canvas canvas, String text, Offset point, {bool right = false}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style:
                TextStyle(fontFamily: 'NanumGothic', fontSize: 11, color: ink)),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: math.max(1, canvasWidth - 12));
    painter.paint(canvas, point - Offset(right ? painter.width : 0, 0));
    painter.dispose();
  }

  String time(DateTime value) {
    final t = value.toLocal();
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvasWidth = size.width;
    if (size.width <= 64 || size.height <= 60) return;
    final area = Rect.fromLTRB(44, 14, size.width - 12, size.height - 38);
    final points = records.where((r) => r.percent != null).toList();
    final top = math.max(
        100.0, points.fold<double>(0, (n, r) => math.max(n, r.percent!)));
    final rounded = (top / 20).ceilToDouble() * 20.0;
    final maximum = rounded.isFinite ? rounded : top;
    for (var i = 0; i < 3; i++) {
      final y = area.bottom - area.height * i / 2;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y),
          Paint()..color = ink.withValues(alpha: .16));
      label(canvas, '${(maximum * i / 2).toStringAsFixed(0)}%',
          Offset(area.left - 8, y - 7),
          right: true);
    }
    if (records.isEmpty) {
      label(canvas, '아직 조회 기록이 없습니다.', Offset(area.left + 12, area.center.dy));
      return;
    }
    final first = records.first.at, last = records.last.at;
    final span = last.difference(first).inMilliseconds;
    Offset position(DeviceReading r) => Offset(
        span <= 0
            ? area.center.dx
            : area.left +
                area.width * r.at.difference(first).inMilliseconds / span,
        area.bottom - area.height * (r.percent! / maximum));
    label(canvas, '실선: 측정 연결 · 점선: 조회 공백', Offset(area.left, 0));
    if (points.isEmpty) {
      label(canvas, '유효한 측정값이 없습니다.', Offset(area.left + 8, area.center.dy));
    }
    DeviceReading? prior;
    var unknown = false;
    for (final r in records) {
      if (r.percent == null) {
        unknown = true;
        continue;
      }
      final point = position(r);
      if (prior != null) {
        final from = position(prior);
        final gap =
            unknown || r.at.difference(prior.at) > const Duration(minutes: 15);
        final paint = Paint()
          ..color = color.withValues(alpha: gap ? .7 : 1)
          ..strokeWidth = gap ? 2 : 3
          ..strokeCap = StrokeCap.round;
        if (gap) {
          final distance = (point - from).distance;
          if (distance > 0) {
            final direction = (point - from) / distance;
            for (var offset = 0.0; offset < distance; offset += 9) {
              canvas.drawLine(from + direction * offset,
                  from + direction * math.min(offset + 5, distance), paint);
            }
          }
        } else {
          canvas.drawLine(from, point, paint);
        }
      }
      canvas.drawCircle(point, 3.5, Paint()..color = color);
      prior = r;
      unknown = false;
    }
    label(canvas, time(first), Offset(area.left, area.bottom + 12));
    if (span > 0 && area.width >= 190) {
      label(canvas, time(last), Offset(area.right, area.bottom + 12),
          right: true);
    }
  }

  @override
  bool shouldRepaint(covariant _Chart old) =>
      !listEquals(old.records, records) || old.color != color || old.ink != ink;
}
