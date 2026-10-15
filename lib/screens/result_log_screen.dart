import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';
import '../services/work_log_service.dart';
import '../services/result_submission_service.dart';

class ResultLogScreen extends StatefulWidget {
  const ResultLogScreen({super.key});
  @override
  State<ResultLogScreen> createState() => _ResultLogScreenState();
}

class _ResultLogScreenState extends State<ResultLogScreen> {
  late Future<List<Map<String, dynamic>>> records;
  final api = ApiService();
  bool sending = false;
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
    final id = await TokenStorageService().userId();
    if (id == null) throw StateError('No session');
    return WorkLogService().load(id);
  }

  Future<void> retry(Map<String, dynamic> record) async {
    if (sending || record['server_submitted'] == true) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('작업 기록')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
          future: records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('기록을 불러오지 못했습니다.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            if (data.isEmpty) {
              return const Center(child: Text('저장된 작업 기록이 없습니다.'));
            }
            return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, i) {
                  final record = data[i];
                  final sent = record['server_submitted'] == true;
                  return ListTile(
                      title: Text('${record['work_name']}'),
                      subtitle: Text(
                          '${record['ended_at']}\n${sent ? '서버 저장 완료' : '서버 저장 미확인'}'),
                      isThreeLine: true,
                      trailing: !sent && record['request'] is Map
                          ? IconButton(
                              tooltip: '결과 재전송',
                              onPressed: sending ? null : () => retry(record),
                              icon: const Icon(Icons.cloud_upload))
                          : null,
                      onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                                  title: const Text('답변 기록'),
                                  content: SingleChildScrollView(
                                      child: Text((record['answers'] as List)
                                          .map((a) =>
                                              '${a['step_name']}: ${a['answer_label']}')
                                          .join('\n'))),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('닫기'))
                                  ])));
                });
          }));
}
