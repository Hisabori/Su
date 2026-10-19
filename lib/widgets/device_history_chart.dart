import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/device_history_service.dart';

class DeviceHistoryChart extends StatelessWidget {
  const DeviceHistoryChart({super.key, required this.records});
  final List<DeviceReading> records;
  @override
  Widget build(BuildContext context) {
    final valid = records.where((r) => r.percent != null).length;
    return Semantics(
        label:
            '페트병 수거기 적재율 추이 그래프. 유효한 측정 $valid회. 자세한 수치는 아래 기록에서 확인할 수 있습니다.',
        child: SizedBox(
            height: 240,
            child: CustomPaint(
                painter: _Chart(records, Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.onSurface))));
  }
}

class _Chart extends CustomPainter {
  _Chart(this.records, this.color, this.ink);
  final List<DeviceReading> records;
  final Color color, ink;
  void label(Canvas canvas, String text, Offset point, {bool right = false}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style:
                TextStyle(fontFamily: 'NanumGothic', fontSize: 11, color: ink)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, point - Offset(right ? painter.width : 0, 0));
  }

  String time(DateTime value) {
    final t = value.toLocal();
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(44, 14, size.width - 12, size.height - 38);
    final points = records.where((r) => r.percent != null).toList();
    final top = math.max(
        100.0, points.fold<double>(0, (n, r) => math.max(n, r.percent!)));
    final rounded = (top / 20).ceilToDouble() * 20.0;
    final maximum = rounded.isFinite ? rounded : top;
    for (var i = 0; i < 3; i++) {
      final y = area.bottom - area.height * i / 2;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y),
          Paint()..color = const Color(0xFFE1E9EF));
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
    DeviceReading? prior;
    for (final r in records) {
      if (r.percent == null) {
        prior = null;
        continue;
      }
      final point = position(r);
      if (prior != null &&
          r.at.difference(prior.at) <= const Duration(minutes: 15)) {
        canvas.drawLine(
            position(prior),
            point,
            Paint()
              ..color = color
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      }
      canvas.drawCircle(point, 3.5, Paint()..color = color);
      prior = r;
    }
    label(canvas, time(first), Offset(area.left, area.bottom + 12));
    if (span > 0) {
      label(canvas, time(last), Offset(area.right, area.bottom + 12),
          right: true);
    }
  }

  @override
  bool shouldRepaint(covariant _Chart old) =>
      old.records != records || old.color != color || old.ink != ink;
}
