import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/community_utils.dart';
import '../services/community_photo.dart';
import 'community_detail_screen.dart';
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
  bool loading = true, deleting = false, onlyMine = false, isAdmin = false;
  String query = '';
  List<Map<String, dynamic>> get visiblePosts => posts
      .where((p) =>
          (!onlyMine || p['mine'] == true) &&
          [p['title'], p['body'], p['author']]
              .join(' ')
              .toLowerCase()
              .contains(query.trim().toLowerCase()))
      .toList();
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
    if (more && loading) return;
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
        isAdmin = result['me'] is Map && result['me']['isAdmin'] == true;
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
          if (isAdmin)
            IconButton(
                tooltip: '신고 관리',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            CommunityReportsScreen(service: service)))),
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
                          TextField(
                              onChanged: (v) => setState(() => query = v),
                              decoration: const InputDecoration(
                                  labelText: '불러온 글 검색',
                                  hintText: '제목 · 내용 · 작성자',
                                  prefixIcon: Icon(Icons.search))),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: [
                            FilterChip(
                                label: const Text('내 글만'),
                                selected: onlyMine,
                                onSelected: (v) =>
                                    setState(() => onlyMine = v)),
                            Chip(label: Text('불러온 글 ${posts.length}개'))
                          ]),
                          const SizedBox(height: 12),
                          if (!loading &&
                              posts.isNotEmpty &&
                              visiblePosts.isEmpty)
                            const Text('검색 조건에 맞는 글이 없어요. 이전 글도 불러와 보세요.'),
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
                          for (final post in visiblePosts)
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
                                          if (post['pinned'] == true)
                                            const Chip(label: Text('공지')),
                                          if (post['hasImage'] == true)
                                            const Text('사진 첨부'),
                                          Text('${post['title']}',
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.4)),
                                          const SizedBox(height: 10),
                                          Text('${post['body']}',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16, height: 1.7)),
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                              onPressed: () async {
                                                await Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            CommunityDetailScreen(
                                                                service:
                                                                    service,
                                                                id: post['id']
                                                                    as String)));
                                                if (mounted) load();
                                              },
                                              icon: const Icon(
                                                  Icons.chat_bubble_outline),
                                              label: const Text('댓글 · 좋아요')),
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
  late final String id = newCommunityId();
  Map<String, dynamic>? image;
  bool picking = false;
  Future<void> pickPhoto() async {
    if (picking || saving) return;
    setState(() => picking = true);
    try {
      final result = await pickCommunityPhoto();
      if (mounted && result != null) setState(() => image = result);
    } catch (_) {
      if (mounted) {
        setState(() => error = '사진을 읽지 못했습니다. JPG·PNG 사진을 다시 선택해 주세요.');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
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
      await widget.service.request('create', {
        'id': id,
        'title': title.text,
        'body': body.text,
        if (image != null) 'image': image
      });
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
      canPop: !saving && !picking,
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
                  if (communityPhotoAvailable)
                    OutlinedButton.icon(
                        onPressed: saving || picking ? null : pickPhoto,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(picking ? '사진 준비 중…' : '사진 첨부')),
                  if (image != null) ...[
                    Image.memory(base64Decode(image!['data'] as String),
                        height: 180, semanticLabel: '첨부할 사진'),
                    TextButton(
                        onPressed:
                            saving ? null : () => setState(() => image = null),
                        child: const Text('사진 제거')),
                    const Text('사진 1장 · 최대 512KB · 위치 정보 없이 전송'),
                  ],
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child:
                            Semantics(liveRegion: true, child: Text(error!))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: saving || picking ? null : save,
                      child: Text(saving ? '등록 중…' : '글 등록')),
                ]))),
      ));
}
