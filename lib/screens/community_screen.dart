import '../widgets/app_icon.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import '../services/community_draft_service.dart';
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
  final search = TextEditingController();
  int loadGeneration = 0;
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
    search.dispose();
    service.close();
    super.dispose();
  }

  String message(Object e) =>
      e is ApiFailure ? e.message : '요청을 완료하지 못했습니다. 다시 시도해 주세요.';
  Future<void> load({bool more = false}) async {
    if (more && loading) return;
    final generation = ++loadGeneration;
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
      if (!mounted || generation != loadGeneration) return;
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
      if (mounted && generation == loadGeneration) {
        setState(() => error = message(e));
      }
    } finally {
      if (mounted && generation == loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openPost(Map<String, dynamic> post) async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CommunityDetailScreen(
                service: service, id: post['id'] as String)));
    if (mounted) load();
  }

  void resetFilters() {
    search.clear();
    setState(() {
      query = '';
      onlyMine = false;
    });
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
                icon: const AppIcon(AppIconKind.compose),
                label: const Text('글쓰기')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        children: [
                          if (AppStyle.isBeta(context))
                            Semantics(
                                container: true,
                                explicitChildNodes: true,
                                child: GlassSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(children: [
                                            Icon(Icons.spa_outlined,
                                                color: AppStyle.teal, size: 18),
                                            SizedBox(width: 8),
                                            Text('우리의 작은 쉼터',
                                                style: TextStyle(
                                                    color: AppStyle.teal,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700))
                                          ]),
                                          const SizedBox(height: 14),
                                          const Text('함께 나누는 이야기',
                                              style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppStyle.navy)),
                                          const SizedBox(height: 10),
                                          Text(
                                              me == null
                                                  ? '동료들과 일상의 이야기를 나눠보세요.'
                                                  : '$me 님, 오늘의 이야기를 들려주세요.',
                                              style: const TextStyle(
                                                  height: 1.7,
                                                  color: AppStyle.muted)),
                                        ])))
                          else ...[
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
                          ],
                          if (AppStyle.isBeta(context))
                            const SizedBox(height: 24),
                          TextField(
                              controller: search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              onChanged: (v) => setState(() => query = v),
                              decoration: InputDecoration(
                                  suffixIcon: query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: '검색 지우기',
                                          onPressed: () {
                                            search.clear();
                                            setState(() => query = '');
                                          },
                                          icon: const Icon(Icons.close)),
                                  labelText: '불러온 글 검색',
                                  hintText: '제목 · 내용 · 작성자',
                                  prefixIcon: const Icon(Icons.search))),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: [
                            FilterChip(
                                label: const Text('내 글만'),
                                selected: onlyMine,
                                onSelected: (v) =>
                                    setState(() => onlyMine = v)),
                            Chip(label: Text('불러온 글 ${posts.length}개')),
                            if (query.isNotEmpty || onlyMine)
                              TextButton(
                                  onPressed: resetFilters,
                                  child: const Text('필터 초기화'))
                          ]),
                          const SizedBox(height: 12),
                          if (!loading &&
                              posts.isNotEmpty &&
                              visiblePosts.isEmpty)
                            const Text('검색 조건에 맞는 글이 없어요. 이전 글도 불러와 보세요.'),
                          if (error != null)
                            GlassCard(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(children: [
                                      Text(error!),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                          onPressed: loading ? null : load,
                                          child: const Text('다시 시도'))
                                    ]))),
                          if (loading && posts.isNotEmpty)
                            const LinearProgressIndicator(),
                          if (loading && posts.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    Center(child: CircularProgressIndicator())),
                          if (!loading && error == null && posts.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 64),
                                child: Column(children: [
                                  AppIcon(AppIconKind.community, size: 48),
                                  SizedBox(height: 16),
                                  Text('아직 이야기가 없어요.',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 8),
                                  Text('첫 번째 이야기를 남겨보세요.')
                                ])),
                          for (final post in visiblePosts)
                            GlassCard(
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
                                          InkWell(
                                              onTap: () => openPost(post),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 6),
                                                  child: Text(
                                                      '${post['title']}',
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          height: 1.4)))),
                                          const SizedBox(height: 10),
                                          Text('${post['body']}',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16, height: 1.7)),
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                              onPressed: () => openPost(post),
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
      {super.key, required this.service, required this.name, this.post});
  final CommunityService service;
  final String? name;
  final Map<String, dynamic>? post;
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final title = TextEditingController(), body = TextEditingController();
  late final String id = newCommunityId();
  final drafts = CommunityDraftService();
  Timer? draftTimer;
  int? draftUser;
  bool draftReady = false, published = false;
  String? draftStatus;
  bool get editing => widget.post != null;
  @override
  void initState() {
    super.initState();
    restoreDraft();
  }

  Future<void> restoreDraft() async {
    try {
      if (editing) {
        title.text = '${widget.post!['title']}';
        body.text = '${widget.post!['body']}';
      } else {
        draftUser = await widget.service.tokens.userId();
        final d = draftUser == null ? null : await drafts.load(draftUser!);
        if (!mounted) return;
        if (d != null) {
          title.text = d['title'] as String;
          body.text = d['body'] as String;
          draftStatus = '임시저장한 글을 불러왔습니다.';
        }
      }
    } catch (_) {
      draftStatus = '임시저장을 확인하지 못했습니다.';
    } finally {
      if (mounted) {
        setState(() => draftReady = true);
        title.addListener(scheduleDraft);
        body.addListener(scheduleDraft);
      }
    }
  }

  void scheduleDraft() {
    if (editing || published) return;
    draftTimer?.cancel();
    draftTimer =
        Timer(const Duration(milliseconds: 600), () => unawaited(saveDraft()));
  }

  Future<void> saveDraft() async {
    final user = draftUser;
    if (editing || published || user == null) return;
    final t = title.text, b = body.text;
    try {
      await drafts.save(user, t, b);
      if (mounted) setState(() => draftStatus = '제목·내용 임시저장됨 · 사진은 제외');
    } catch (_) {
      if (mounted) {
        setState(() => draftStatus = '임시저장에 실패했습니다. 내용을 복사해 보관해 주세요.');
      }
    }
  }

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
    draftTimer?.cancel();
    title.removeListener(scheduleDraft);
    body.removeListener(scheduleDraft);
    if (!editing && !published && draftReady) {
      unawaited(saveDraft());
    }
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
      draftTimer?.cancel();
      await widget.service.request(editing ? 'edit' : 'create', {
        'id': editing ? widget.post!['id'] : id,
        if (editing) 'mutationId': id,
        'title': title.text,
        'body': body.text,
        if (image != null) 'image': image
      });
      published = true;
      if (!editing && draftUser != null) {
        try {
          await drafts.clear(draftUser!);
        } catch (_) {
          /* Posting succeeded; never resend because draft cleanup failed. */
        }
      }
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

  Widget submitButton() => FilledButton(
      onPressed: saving || picking || !draftReady ? null : save,
      child: Text(saving
          ? '저장 중…'
          : editing
              ? '수정 저장'
              : '글 등록'));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving && !picking,
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? '이야기 수정' : '이야기 쓰기')),
        bottomNavigationBar: AppStyle.isBeta(context)
            ? Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Center(
                            heightFactor: 1,
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 760),
                                child: GlassSurface(
                                    padding: const EdgeInsets.all(10),
                                    child: SizedBox(
                                        width: double.infinity,
                                        child: submitButton())))))))
            : null,
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('작성자 · ${widget.name ?? '로그인 사용자'}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 24),
                      TextField(
                          controller: title,
                          enabled: !saving && draftReady,
                          maxLength: 80,
                          decoration: const InputDecoration(
                              labelText: '제목', hintText: '어떤 이야기를 나누고 싶으세요?')),
                      const SizedBox(height: 20),
                      TextField(
                          controller: body,
                          enabled: !saving && draftReady,
                          maxLength: 2000,
                          minLines: 8,
                          maxLines: 16,
                          decoration: const InputDecoration(
                              labelText: '내용',
                              alignLabelWithHint: true,
                              hintText: '동료들에게 전하고 싶은 이야기를 적어주세요.')),
                      if (editing) const Text('수정 시 기존 사진은 유지됩니다.'),
                      if (!editing && communityPhotoAvailable)
                        OutlinedButton.icon(
                            onPressed: saving || picking ? null : pickPhoto,
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(picking ? '사진 준비 중…' : '사진 첨부')),
                      if (image != null) ...[
                        Image.memory(base64Decode(image!['data'] as String),
                            height: 180, semanticLabel: '첨부할 사진'),
                        TextButton(
                            onPressed: saving
                                ? null
                                : () => setState(() => image = null),
                            child: const Text('사진 제거')),
                        const Text('사진 1장 · 최대 512KB · 위치 정보 없이 전송'),
                      ],
                      if (!draftReady) const LinearProgressIndicator(),
                      if (!editing) ...[
                        if (draftStatus != null)
                          Text(draftStatus!,
                              style: const TextStyle(fontSize: 12)),
                        TextButton(
                            onPressed: saving || !draftReady ? null : saveDraft,
                            child: const Text('제목·내용 임시저장')),
                      ],
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Semantics(
                                liveRegion: true, child: Text(error!))),
                      const SizedBox(height: 20),
                      if (!AppStyle.isBeta(context)) submitButton(),
                    ]))),
      ));
}
