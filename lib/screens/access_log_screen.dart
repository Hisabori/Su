import 'package:flutter/material.dart';
import '../services/access_service.dart';
import '../services/api_service.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import '../widgets/loading_skeleton.dart';

class AccessLogScreen extends StatefulWidget {
  const AccessLogScreen({super.key, this.service});
  final AccessService? service;
  @override
  State<AccessLogScreen> createState() => _AccessLogScreenState();
}

class _AccessLogScreenState extends State<AccessLogScreen> {
  late final service = widget.service ?? AccessService();
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  String? cursor, error;
  bool loading = true, loadingMore = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.close();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (more && loading) return;
    setState(() {
      loading = true;
      loadingMore = more;
      error = null;
    });
    try {
      final result = await service.list(cursor: more ? cursor : null);
      final records = (result['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (mounted) {
        setState(() {
          rows = more
              ? [
                  ...rows,
                  ...records.where((r) => !rows.any((old) =>
                      old['event_id'] == r['event_id'] &&
                      old['user_id'] == r['user_id']))
                ]
              : records;
          cursor = result['cursor'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiFailure ? e.message : '접속 기록을 읽지 못했습니다. [ACC-201]');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String stamp(Object? value) {
    final at = DateTime.tryParse('$value')?.toLocal();
    if (at == null) return '시각 미확인';
    return '${at.year}.${at.month}.${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}';
  }

  String deviceLabel(Map<String, dynamic> row) {
    final client = {
          'web': '웹',
          'ios': 'iOS 앱',
          'android': 'Android 앱',
          'desktop': '데스크톱'
        }[row['client']] ??
        '기기 미확인';
    final os = {
      'ios': 'iOS',
      'android': 'Android',
      'windows': 'Windows',
      'macos': 'macOS',
      'linux': 'Linux'
    }[row['os']];
    final browser = {
      'chrome': 'Chrome',
      'safari': 'Safari',
      'firefox': 'Firefox',
      'edge': 'Edge'
    }[row['browser']];
    return [
      client,
      if (os != null && row['os'] != row['client']) os,
      if (browser != null) browser
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible = rows
        .where((r) => RegExp(r'^\d+$').hasMatch(query)
            ? '${r['user_id']}' == query
            : '${r['name']}'.toLowerCase().contains(query))
        .toList();
    return Scaffold(
        appBar: AppBar(title: const Text('접속 기록'), actions: [
          IconButton(
              tooltip: '접속 기록 새로고침',
              onPressed: loading ? null : load,
              icon: const Icon(Icons.refresh))
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(22),
                        children: [
                          BetaGlass(
                              child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('모든 사용자 접속',
                                            style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    AppStyle.inkOf(context))),
                                        const SizedBox(height: 10),
                                        const Text(
                                            '서버에서 확인한 사용자 ID·이름·접속 시각입니다. 비밀번호 로그인과 앱 진입을 구분해 표시합니다.',
                                            style: TextStyle(height: 1.6)),
                                        const SizedBox(height: 18),
                                        TextField(
                                            controller: search,
                                            onChanged: (_) => setState(() {}),
                                            decoration: const InputDecoration(
                                                labelText: '불러온 접속 기록 검색',
                                                hintText: '서버 ID · 이름',
                                                prefixIcon:
                                                    Icon(Icons.search))),
                                      ]))),
                          const SizedBox(height: 16),
                          if (loading && rows.isEmpty)
                            const LoadingSkeleton(
                                label: '접속 기록을 불러오고 있어요.', scrollable: false),
                          Text('불러온 접속 ${rows.length}건 · 전체 사용자 대상',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppStyle.mutedOf(context))),
                          if (loading && rows.isNotEmpty && !loadingMore)
                            const LinearProgressIndicator(),
                          if (error != null) Text(error!),
                          if (!loading && error == null && visible.isEmpty)
                            const Text(
                                '불러온 기록에 해당하는 접속이 없습니다. 이전 접속 기록도 확인해 주세요.'),
                          for (final row in visible)
                            GlassCard(
                                semanticContainer: false,
                                margin: const EdgeInsets.only(bottom: 14),
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${row['name']} · ID ${row['user_id']}',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppStyle.blueOf(
                                                      context))),
                                          const SizedBox(height: 10),
                                          Text(stamp(row['at'])),
                                          const SizedBox(height: 6),
                                          Text(
                                              '${row['kind'] == 'password_login' ? '비밀번호 로그인' : '앱·자동 접속'} · ${deviceLabel(row)}'),
                                        ]))),
                          if (loading && loadingMore)
                            const LoadingSkeleton(
                                label: '이전 접속 기록을 불러오고 있어요.',
                                scrollable: false,
                                compact: true),
                          if (cursor != null)
                            OutlinedButton(
                                onPressed:
                                    loading ? null : () => load(more: true),
                                child: const Text('이전 접속 기록 불러오기')),
                        ])))));
  }
}
