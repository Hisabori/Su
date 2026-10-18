import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';
import '../services/work_log_service.dart';
import '../services/result_submission_service.dart';
import '../widgets/completion_panel.dart' show completionTime;

class ResultLogScreen extends StatefulWidget {
  const ResultLogScreen({super.key, this.readOnlyRecords});
  final List<Map<String, dynamic>>? readOnlyRecords;
  @override
  State<ResultLogScreen> createState() => _ResultLogScreenState();
}

class _ResultLogScreenState extends State<ResultLogScreen> {
  late Future<List<Map<String, dynamic>>> records;
  final api = ApiService();
  bool sending = false, showAll = false;
  @override
  void initState() {
    super.initState();
    records = load();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (widget.readOnlyRecords != null) return widget.readOnlyRecords!;
    final id = await TokenStorageService().userId();
    if (id == null) throw StateError('No session');
    return WorkLogService().load(id);
  }

  Future<void> retry(Map<String, dynamic> record) async {
    if (widget.readOnlyRecords != null ||
        sending ||
        record['server_submitted'] == true) {
      return;
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('저장되지 않은 결과를 전송할까요?'),
                content: const Text(
                    '네트워크 오류로 응답만 받지 못한 경우에는 서버에 이미 저장돼 있을 수 있습니다. 서버 기록을 확인한 뒤 전송하세요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('전송'))
                ]));
    if (confirm != true || !mounted) return;
    setState(() => sending = true);
    try {
      final id = await TokenStorageService().userId();
      if (id == null) throw ApiFailure('다시 로그인해 주세요.');
      final outcome =
          await ResultSubmissionService(api, WorkLogService()).send(id, record);
      record['server_submitted'] = true;
      record['result_id'] = outcome.resultId;
      if (!outcome.persistedLocally && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서버 저장 완료. 기기 내 기록 갱신에 실패했습니다.')));
      }
      if (mounted) setState(() => records = load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiFailure ? e.message : '결과 저장을 확인하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  DateTime? date(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  bool isToday(Map<String, dynamic> record) {
    final end = date(record['ended_at']);
    final now = DateTime.now();
    return end != null &&
        end.year == now.year &&
        end.month == now.month &&
        end.day == now.day;
  }

  String stamp(Object? value) {
    final time = date(value);
    return time == null
        ? '시각 미확인'
        : '${time.month}월 ${time.day}일 ${completionTime(time)}';
  }

  List<Map> answersOf(Map<String, dynamic> record) => record['answers'] is List
      ? (record['answers'] as List).whereType<Map>().toList()
      : [];
  Widget stat(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 84,
            child:
                Text(label, style: const TextStyle(color: Color(0xFF626A70)))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]));
  void detail(Map<String, dynamic> record) {
    final answers = answersOf(record);
    showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
              backgroundColor: const Color(0xFFEDF1F6),
              title: const Text('일일 근무 성과',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        stat('근무 시작', stamp(record['started_at'])),
                        stat('근무 종료', stamp(record['ended_at'])),
                        const Divider(),
                        if (answers.isEmpty) const Text('상세 답변 기록이 없습니다.'),
                        for (final answer in answers)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('${answer['step_name'] ?? '작업 단계'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    if (answer['question'] is String)
                                      Text(answer['question'] as String),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${answer['answer_label'] ?? '답변 미확인'} · ${stamp(answer['ended_at'])}'),
                                    if (progressOf(answer) != null) ...[
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                          value: progressOf(answer),
                                          color: const Color(0xFF104B83),
                                          minHeight: 8),
                                      Text(
                                          '배정 시간 대비 경과 ${(progressOf(answer)! * 100).round()}%'),
                                    ],
                                  ])),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('확인했어요'))
              ],
            ));
  }

  double? progressOf(Map answer) {
    final target = num.tryParse('${answer['work_seconds']}');
    final start = date(answer['started_at']), end = date(answer['ended_at']);
    if (target == null ||
        target <= 0 ||
        start == null ||
        end == null ||
        end.isBefore(start)) {
      return null;
    }
    return (end.difference(start).inSeconds / target).clamp(0.0, 1.0);
  }

  Widget recordCard(Map<String, dynamic> record) {
    final sent = record['server_submitted'] == true;
    final request =
        record['request'] is Map ? record['request'] as Map : const {};
    final answers = answersOf(record);
    return Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => detail(record),
            child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text('${record['work_name'] ?? '근무 기록'}',
                                    style: const TextStyle(
                                        color: Color(0xFF104B83),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800))),
                            if (widget.readOnlyRecords == null &&
                                !sent &&
                                record['request'] is Map)
                              IconButton(
                                  tooltip: '결과 재전송',
                                  onPressed:
                                      sending ? null : () => retry(record),
                                  icon: const Icon(Icons.cloud_upload)),
                          ]),
                      const SizedBox(height: 10),
                      Text(sent ? '서버 저장 완료' : '서버 저장 미확인',
                          style: TextStyle(
                              color: sent
                                  ? const Color(0xFF187B49)
                                  : const Color(0xFFAE4C19))),
                      const Divider(height: 28),
                      stat('근무 시작', stamp(record['started_at'])),
                      stat('근무 종료', stamp(record['ended_at'])),
                      stat(
                          '근무 시간',
                          request['work_minutes'] == null
                              ? '미확인'
                              : '${request['work_minutes']}분'),
                      stat(
                          '휴식',
                          request['rest_minutes'] == null
                              ? '시간 미확인'
                              : '${request['rest_minutes']}분'),
                      const SizedBox(height: 12),
                      Text('답변 ${answers.length}개',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () => detail(record),
                              child: const Text('답변 기록 보기'))),
                    ]))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFEDF1F6),
      appBar: AppBar(
          backgroundColor: const Color(0xFFEDF1F6),
          title: Text(showAll ? '근무 기록' : '오늘의 근무 기록')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
          future: records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('기록을 불러오지 못했습니다.'),
                TextButton(
                    onPressed: () => setState(() => records = load()),
                    child: const Text('다시 시도')),
              ]));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final visible = snapshot.data!
                .where((r) =>
                    showAll || isToday(r) || r['server_submitted'] != true)
                .toList();
            return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Row(children: [
                        ChoiceChip(
                            label: const Text('오늘'),
                            selected: !showAll,
                            onSelected: (_) => setState(() => showAll = false)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                            label: const Text('전체'),
                            selected: showAll,
                            onSelected: (_) => setState(() => showAll = true)),
                      ]),
                      const SizedBox(height: 14),
                      const Text('이 기기에 저장된 기록입니다. 저장 미확인 기록은 날짜와 관계없이 표시합니다.',
                          style: TextStyle(color: Color(0xFF626A70))),
                      const SizedBox(height: 20),
                      if (visible.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('표시할 근무 기록이 없습니다. 전체 기록도 확인해 주세요.')),
                      ...visible.map(recordCard),
                    ])));
          }));
}
