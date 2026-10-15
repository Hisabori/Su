import 'package:flutter/material.dart';

import '../models/work_info.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

class WorkScreen extends StatefulWidget {
  const WorkScreen({super.key});
  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  final api = ApiService();
  final tts = TtsService();
  WorkInfo? work;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    api.close();
    tts.stop();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.getWorkInfo();
      if (mounted) setState(() => work = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure ? e.message : '작업 정보를 불러오지 못했습니다.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    try {
      await api.logoutLocally();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('로그아웃에 실패했습니다.')));
      }
    }
  }

  Future<void> readWork() async {
    try {
      await tts.speak(work!.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('읽어주기를 시작하지 못했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('수호천사'),
          actions: [
            IconButton(
              onPressed: logout,
              icon: const Icon(Icons.logout),
              tooltip: '로그아웃',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: loading
                  ? const CircularProgressIndicator()
                  : error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(error!),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: load, child: const Text('다시 시도')),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(
                              '오늘의 작업',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      work!.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    if (work!.workMinutes != null)
                                      Text('작업 시간: ${work!.workMinutes}분'),
                                    if (work!.restMinutes != null)
                                      Text('휴식 시간: ${work!.restMinutes}분'),
                                    if (work!.startTime != null)
                                      Text('시작: ${work!.startTime}'),
                                    if (work!.endTime != null)
                                      Text('종료: ${work!.endTime}'),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: readWork,
                                      icon: const Icon(Icons.volume_up),
                                      label: const Text('읽어주기'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      );
}
