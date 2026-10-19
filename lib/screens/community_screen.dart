import 'package:flutter/material.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../services/community_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final service = CommunityService();
  List<Map<String, dynamic>> posts = [];
  String? error, cursor, me;
  bool loading = true, deleting = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.close();
    super.dispose();
  }

  String message(Object e) =>
      e is ApiFailure ? e.message : '요청을 완료하지 못했습니다. 다시 시도해 주세요.';
  Future<void> load({bool more = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await service
          .request('list', {if (more && cursor != null) 'cursor': cursor});
      final rows = (result['posts'] as List)
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      if (!mounted) return;
      setState(() {
        posts = more
            ? [
                ...posts,
                ...rows.where((r) => !posts.any((p) => p['id'] == r['id']))
              ]
            : rows;
        cursor = result['cursor'] as String?;
        me = result['me'] is Map ? result['me']['name'] as String? : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> compose() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => CommunityComposer(service: service, name: me)));
    if (saved == true && mounted) load();
  }

  Future<void> remove(Map<String, dynamic> post) async {
    if (deleting) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('이 글을 삭제할까요?'),
                content: const Text('삭제한 글은 복구할 수 없습니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('삭제'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await service.request('delete', {'id': post['id']});
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message(e))));
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  String stamp(Object? value) {
    final ms = value is num ? value.toInt() : 0;
    if (ms <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${date.month}.${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('커뮤니티'), actions: [
          IconButton(
              tooltip: '새로고침',
              onPressed: loading ? null : load,
              icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: me == null
            ? null
            : FloatingActionButton.extended(
                onPressed: loading ? null : compose,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('글쓰기')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        children: [
                          const Text('함께 나누는 이야기',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Text(
                              me == null
                                  ? '동료들과 일상의 이야기를 나눠보세요.'
                                  : '$me 님, 오늘의 이야기를 들려주세요.',
                              style: const TextStyle(height: 1.6)),
                          const SizedBox(height: 24),
                          if (error != null)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(children: [
                                      Text(error!),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                          onPressed: loading ? null : load,
                                          child: const Text('다시 시도'))
                                    ]))),
                          if (loading)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    Center(child: CircularProgressIndicator())),
                          if (!loading && error == null && posts.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 64),
                                child: Column(children: [
                                  Icon(Icons.forum_outlined, size: 48),
                                  SizedBox(height: 16),
                                  Text('아직 이야기가 없어요.',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 8),
                                  Text('첫 번째 이야기를 남겨보세요.')
                                ])),
                          for (final post in posts)
                            Card(
                                semanticContainer: false,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            const CircleAvatar(
                                                radius: 18,
                                                child: Icon(
                                                    Icons.person_outline,
                                                    size: 20)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text('${post['author']}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                  Text(stamp(post['createdAt']),
                                                      style: const TextStyle(
                                                          fontSize: 12))
                                                ])),
                                            if (post['mine'] == true)
                                              IconButton(
                                                  tooltip: '내 글 삭제',
                                                  onPressed: deleting
                                                      ? null
                                                      : () => remove(post),
                                                  icon: const Icon(
                                                      Icons.delete_outline))
                                          ]),
                                          const SizedBox(height: 18),
                                          Text('${post['title']}',
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.4)),
                                          const SizedBox(height: 10),
                                          SelectableText('${post['body']}',
                                              style: const TextStyle(
                                                  fontSize: 16, height: 1.7)),
                                        ]))),
                          if (cursor != null && !loading)
                            OutlinedButton(
                                onPressed: () => load(more: true),
                                child: const Text('이전 글 더 보기')),
                        ])))),
      );
}

class CommunityComposer extends StatefulWidget {
  const CommunityComposer(
      {super.key, required this.service, required this.name});
  final CommunityService service;
  final String? name;
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final title = TextEditingController(), body = TextEditingController();
  late final String id = newPostId();
  String newPostId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch}-${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      setState(() => error = '제목과 내용을 입력해 주세요.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.request(
          'create', {'id': id, 'title': title.text, 'body': body.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiFailure ? e.message : '글을 등록하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('이야기 쓰기')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text('작성자 · ${widget.name ?? '로그인 사용자'}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: title,
                      enabled: !saving,
                      maxLength: 80,
                      decoration: const InputDecoration(
                          labelText: '제목', hintText: '어떤 이야기를 나누고 싶으세요?')),
                  const SizedBox(height: 20),
                  TextField(
                      controller: body,
                      enabled: !saving,
                      maxLength: 2000,
                      minLines: 8,
                      maxLines: 16,
                      decoration: const InputDecoration(
                          labelText: '내용',
                          alignLabelWithHint: true,
                          hintText: '동료들에게 전하고 싶은 이야기를 적어주세요.')),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child:
                            Semantics(liveRegion: true, child: Text(error!))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? '등록 중…' : '글 등록')),
                ]))),
      ));
}
