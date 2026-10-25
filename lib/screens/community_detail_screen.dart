import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/community_service.dart';
import '../utils/community_utils.dart';
import 'community_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen(
      {super.key, required this.service, required this.id});
  final CommunityService service;
  final String id;
  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  Map<String, dynamic>? post;
  List<Map<String, dynamic>> comments = [];
  final text = TextEditingController();
  String? cursor, error, commentId;
  bool loading = true,
      busy = false,
      liked = false,
      admin = false,
      likesMore = false;
  int likes = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String message(Object e) => e is ApiFailure ? e.message : '요청을 완료하지 못했습니다.';
  Future<void> load({bool more = false}) async {
    if (more && loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await widget.service
          .request('detail', {'id': widget.id, if (more) 'cursor': cursor});
      if (!mounted) return;
      final rows = (r['comments'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      setState(() {
        post = Map<String, dynamic>.from(r['post'] as Map);
        comments = more
            ? [
                ...comments,
                ...rows.where((r) => !comments.any((p) => p['id'] == r['id']))
              ]
            : rows;
        cursor = r['cursor'] as String?;
        liked = r['liked'] == true;
        likes = (r['likes'] as num?)?.toInt() ?? 0;
        likesMore = r['likesMore'] == true;
        admin = r['isAdmin'] == true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          if (e is ApiFailure && [401, 403, 404].contains(e.code)) {
            post = null;
            comments = [];
          }
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> act(String action, Map<String, dynamic> data) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await widget.service.request(action, {'id': widget.id, ...data});
      if (mounted) await load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message(e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submitComment() async {
    if (text.text.trim().isEmpty || busy) return;
    commentId ??= newCommunityId();
    if (await act(
            'comment_create', {'commentId': commentId, 'body': text.text}) &&
        mounted) {
      text.clear();
      commentId = null;
    }
  }

  Future<void> editPost() async {
    if (post == null || busy) return;
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => CommunityComposer(
                service: widget.service,
                name: post!['author'] as String?,
                post: post)));
    if (saved == true && mounted) await load();
  }

  Future<void> editComment(Map<String, dynamic> comment) async {
    final input = TextEditingController(text: '${comment['body']}');
    final key = GlobalKey<FormState>();
    final value = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('댓글 수정'),
                content: Form(
                    key: key,
                    child: TextFormField(
                        controller: input,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 5,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '내용을 입력해 주세요.'
                            : null,
                        decoration:
                            const InputDecoration(labelText: '수정할 댓글'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () {
                        if (key.currentState!.validate()) {
                          Navigator.pop(d, input.text.trim());
                        }
                      },
                      child: const Text('댓글 수정 저장'))
                ]));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (value != null && mounted) {
      await act('comment_edit', {
        'commentId': comment['id'],
        'mutationId': newCommunityId(),
        'body': value
      });
    }
  }

  Future<void> report() async {
    final input = TextEditingController();
    String? validation;
    final reason = await showDialog<String>(
        context: context,
        builder: (d) => StatefulBuilder(
            builder: (d, update) => AlertDialog(
                    title: const Text('글 신고'),
                    content: TextField(
                        controller: input,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                            labelText: '신고 사유', errorText: validation)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () {
                            if (input.text.trim().isEmpty) {
                              update(() => validation = '신고 사유를 입력해 주세요.');
                            } else {
                              Navigator.pop(d, input.text.trim());
                            }
                          },
                          child: const Text('신고 접수'))
                    ])));
    // Dialog exit animation may still reference its text controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;
    if (await act('report', {'reason': reason}) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('신고를 접수했습니다.')));
    }
  }

  Widget photo(Object? value) {
    if (value is! Map || value['data'] is! String) {
      return const SizedBox.shrink();
    }
    try {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Image.memory(base64Decode(value['data'] as String),
              semanticLabel: '첨부 사진',
              errorBuilder: (_, __, ___) => const Text('사진을 표시하지 못했습니다.')));
    } on FormatException {
      return const Text('사진을 표시하지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('이야기'), actions: [
        IconButton(
            tooltip: '이야기 새로고침',
            onPressed: loading || busy ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (error != null) ...[
                  Text(error!),
                  TextButton(
                      onPressed: loading ? null : load,
                      child: const Text('다시 시도'))
                ],
                if (loading) const LinearProgressIndicator(),
                if (post != null) ...[
                  if (post!['pinned'] == true) const Chip(label: Text('공지')),
                  if (post!['hidden'] == true) const Text('관리자가 숨긴 글입니다.'),
                  Text('${post!['title']}',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                      '${post!['author']} · ${communityStamp(post!['createdAt'])}'),
                  if (post!['updatedAt'] != null)
                    Text('수정 ${communityStamp(post!['updatedAt'])}',
                        style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 24),
                  Text('${post!['body']}',
                      style: const TextStyle(fontSize: 17, height: 1.7)),
                  photo(post!['image']),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    if (post!['mine'] == true)
                      TextButton(
                          onPressed: busy ? null : editPost,
                          child: const Text('내 글 수정')),
                    OutlinedButton.icon(
                        onPressed: busy || loading
                            ? null
                            : () => act('like', {'liked': !liked}),
                        icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border),
                        label: Text(
                            '${liked ? '좋아요 취소' : '좋아요'} $likes${likesMore ? '+' : ''}')),
                    TextButton(
                        onPressed: busy ? null : report,
                        child: const Text('신고하기')),
                    if (admin) ...[
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  'pin', {'enabled': post!['pinned'] != true}),
                          child: Text(
                              post!['pinned'] == true ? '공지 해제' : '공지로 등록')),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  'hide', {'enabled': post!['hidden'] != true}),
                          child: Text(
                              post!['hidden'] == true ? '글 다시 공개' : '글 숨기기')),
                    ]
                  ]),
                  const Divider(height: 40),
                  const Text('댓글',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: text,
                      enabled: !busy,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: '댓글 내용', hintText: '따뜻한 한마디를 남겨보세요.')),
                  Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                          onPressed: busy ? null : submitComment,
                          child: Text(busy ? '처리 중…' : '댓글 등록'))),
                  const SizedBox(height: 20),
                  if (comments.isEmpty && !loading) const Text('첫 댓글을 남겨보세요.'),
                  for (final c in comments)
                    Card(
                        semanticContainer: false,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(
                                            '${c['author']} · ${communityStamp(c['createdAt'])}')),
                                    if (c['mine'] == true)
                                      IconButton(
                                          tooltip: '댓글 수정',
                                          onPressed: busy
                                              ? null
                                              : () => editComment(c),
                                          icon:
                                              const Icon(Icons.edit_outlined)),
                                    if (c['mine'] == true || admin)
                                      IconButton(
                                          tooltip: '댓글 삭제',
                                          onPressed: busy
                                              ? null
                                              : () => act('comment_delete',
                                                  {'commentId': c['id']}),
                                          icon:
                                              const Icon(Icons.delete_outline))
                                  ]),
                                  Text('${c['body']}',
                                      style: const TextStyle(height: 1.6)),
                                  if (c['updatedAt'] != null)
                                    const Text('수정됨',
                                        style: TextStyle(fontSize: 12)),
                                ]))),
                  if (cursor != null)
                    TextButton(
                        onPressed:
                            loading || busy ? null : () => load(more: true),
                        child: const Text('이전 댓글 더 보기')),
                ]
              ]))));
}

class CommunityReportsScreen extends StatefulWidget {
  const CommunityReportsScreen({super.key, required this.service});
  final CommunityService service;
  @override
  State<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends State<CommunityReportsScreen> {
  List<Map<String, dynamic>> rows = [];
  String? error, cursor;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r =
          await widget.service.request('reports', {if (more) 'cursor': cursor});
      if (mounted) {
        setState(() {
          final next = (r['reports'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          rows = more ? [...rows, ...next] : next;
          cursor = r['cursor'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '신고를 불러오지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resolve(String key) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await widget.service.request('report_resolve', {'key': key});
      if (mounted) setState(() => rows.removeWhere((r) => r['key'] == key));
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiFailure ? e.message : '신고 처리를 완료하지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('신고 관리'), actions: [
        IconButton(
            tooltip: '신고 새로고침',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (rows.isEmpty && !loading && error == null)
          const Text('접수된 신고가 없습니다.'),
        for (final r in rows)
          Card(
              semanticContainer: false,
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${r['reporter']} · ${communityStamp(r['createdAt'])}'),
                        const SizedBox(height: 12),
                        Text('${r['reason']}'),
                        Wrap(spacing: 12, children: [
                          TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => CommunityDetailScreen(
                                          service: widget.service,
                                          id: r['postId'] as String))),
                              child: const Text('신고된 글 보기')),
                          TextButton(
                              onPressed: loading
                                  ? null
                                  : () => resolve(r['key'] as String),
                              child: const Text('처리 완료'))
                        ]),
                      ]))),
        if (cursor != null)
          TextButton(
              onPressed: loading ? null : () => load(more: true),
              child: const Text('신고 더 보기')),
      ]));
}
