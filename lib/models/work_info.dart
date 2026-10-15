int? integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value');

class WorkStep {
  final String id, name, prompt;
  final String? videoPath, startTime;
  final int order, workSeconds;
  final List<String> questions;
  WorkStep(
      {required this.id,
      required this.name,
      required this.prompt,
      this.order = 0,
      this.workSeconds = 0,
      this.videoPath,
      this.startTime,
      this.questions = const []});
  factory WorkStep.fromJson(Map<String, dynamic> json) {
    final id = json['step_id'] ?? json['stepid'];
    final name = json['step_name'];
    if (id == null || name is! String) {
      throw const FormatException('Unsupported step schema');
    }
    final question = json['question'];
    return WorkStep(
        order: integer(json['display_order']) ?? 0,
        workSeconds: (integer(json['work_seconds']) ?? 0).clamp(0, 86400),
        id: '$id',
        name: name,
        prompt: [json['start_ment'], json['description'], name]
            .whereType<String>()
            .map((s) => s.trim())
            .firstWhere((s) => s.isNotEmpty, orElse: () => '단계를 확인해 주세요.'),
        videoPath: json['video_path']?.toString(),
        startTime: json['start_time']?.toString(),
        questions: question is String && question.trim().isNotEmpty
            ? [question]
            : question is List
                ? question
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .toList()
                : const []);
  }
}

class WorkInfo {
  final String id, name;
  final int? workMinutes, restMinutes;
  final String? startTime, endTime, workDays;
  final List<WorkStep> steps;
  final int? processVersionId;
  WorkInfo(
      {required this.id,
      required this.name,
      this.workMinutes,
      this.restMinutes,
      this.startTime,
      this.endTime,
      this.workDays,
      this.processVersionId,
      this.steps = const []});
  factory WorkInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['work'] ?? json;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Unsupported work schema');
    }
    final id = raw['work_id'];
    final name = raw['work_name'];
    if (id == null || name is! String) {
      throw const FormatException('Unsupported work schema');
    }
    final steps = json['steps'];
    if (steps != null && steps is! List) {
      throw const FormatException('Unsupported steps schema');
    }
    return WorkInfo(
        id: '$id',
        name: name,
        workMinutes: integer(raw['std_work_minutes']),
        restMinutes: integer(raw['std_rest_minutes']),
        startTime: raw['auto_start_time']?.toString(),
        processVersionId: json['process'] is Map
            ? integer(json['process']['current_version_id'])
            : null,
        endTime: raw['end_time']?.toString(),
        workDays: raw['work_days']?.toString(),
        steps: steps is List
            ? steps.map((s) {
                if (s is! Map<String, dynamic>) {
                  throw const FormatException('Unsupported step schema');
                }
                return WorkStep.fromJson(s);
              }).toList()
            : const []);
  }
}
