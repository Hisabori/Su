class RestWindow {
  final DateTime start, end;
  const RestWindow(this.start, this.end);
}

class WorkSchedule {
  // Original Duration constants: 0x283baec00 and 0xd693a400 microseconds.
  static const workDuration = Duration(hours: 3);
  static const checkoutGrace = Duration(hours: 1);
  static DateTime? timeOnDay(String? text, DateTime day) {
    if (text == null || text.trim().isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text.trim())) {
      return DateTime.tryParse(text)?.toLocal();
    }
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(text.trim());
    if (match == null) return null;
    final h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    final s = int.parse(match[3] ?? '0');
    if (h > 23 || m > 59 || s > 59) return null;
    return DateTime(day.year, day.month, day.day, h, m, s);
  }

  // Recovered from _currentScheduledRestWindow: repeat work+rest cycles.
  static RestWindow? restAt(
      DateTime anchor, DateTime now, int workMinutes, int restMinutes) {
    if (workMinutes <= 0 || restMinutes <= 0 || now.isBefore(anchor)) {
      return null;
    }
    final cycle = (workMinutes + restMinutes) * 60;
    final elapsed = now.difference(anchor).inSeconds;
    final phase = elapsed % cycle;
    if (phase < workMinutes * 60) return null;
    final start = anchor
        .add(Duration(seconds: (elapsed ~/ cycle) * cycle + workMinutes * 60));
    return RestWindow(start, start.add(Duration(minutes: restMinutes)));
  }
}
