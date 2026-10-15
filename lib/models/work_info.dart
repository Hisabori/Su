class WorkInfo {
  final String id;
  final String name;
  final int? workMinutes;
  final int? restMinutes;
  final String? startTime;
  final String? endTime;
  WorkInfo({
    required this.id,
    required this.name,
    this.workMinutes,
    this.restMinutes,
    this.startTime,
    this.endTime,
  });
  factory WorkInfo.fromJson(Map<String, dynamic> json) {
    int? number(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
    final id = json['work_id'];
    final name = json['work_name'];
    if (id == null || name is! String) {
      throw const FormatException('Unsupported work response schema');
    }
    return WorkInfo(
      id: '$id',
      name: name,
      workMinutes: number(json['std_work_minutes']),
      restMinutes: number(json['std_rest_minutes']),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
    );
  }
}
