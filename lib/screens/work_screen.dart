import 'dart:async';
import 'package:flutter/material.dart';
import '../models/work_info.dart';
import '../models/work_result.dart';
import '../models/work_schedule.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/work_log_service.dart';
import '../widgets/work_video.dart';
import 'result_log_screen.dart';

class WorkScreen extends StatefulWidget {
  const WorkScreen({super.key});
  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> with WidgetsBindingObserver {
  final api = ApiService();
  final tts = TtsService();
  final speech = SpeechService();
  final logs = WorkLogService();
  WorkInfo? work;
  String? error;
  bool loading = true,
      started = false,
      saving = false,
      listening = false,
      complete = false,
      awaitingSave = false;
  int index = 0, questionIndex = 0;
  DateTime? startedAt, stepStartedAt, restStartedAt, restUntil;
  int restSeconds = 0;
  final answers = <Map<String, dynamic>>[];
  final deviceChecks = <Map<String, dynamic>>[];
  Map<String, dynamic>? pendingRecord;
  DateTime? scheduleAnchor, plannedStart;
  bool enteringRest = false,
      promptPending = false,
      loggingOut = false,
      automaticEnd = false;
  DateTime? get stepSchedule =>
      started ? WorkSchedule.timeOnDay(step.startTime, startedAt!) : null;
  Timer? timer, videoCompletionTimer;
  WorkStep get step => work!.steps[index];
  String get prompt =>
      step.questions.isEmpty ? step.prompt : step.questions[questionIndex];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    videoCompletionTimer?.cancel();
    speech.stop();
    tts.stop();
    api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      speech.stop();
      tts.stop();
      if (mounted) setState(() => listening = false);
    } else if (mounted) {
      tick();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.getWorkInfo();
      if (mounted) {
        setState(() {
          work = data;
          work!.steps.sort((a, b) => a.order.compareTo(b.order));
          plannedStart = WorkSchedule.timeOnDay(
              work!.steps.isNotEmpty
                  ? work!.steps.first.startTime ?? work!.startTime
                  : work!.startTime,
              DateTime.now());
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiFailure ? e.message : '작업 정보를 불러오지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
      }
    }
  }

  void tick() {
    if (!mounted) return;
    if (complete &&
        !loggingOut &&
        scheduleAnchor != null &&
        !DateTime.now().isBefore(scheduleAnchor!
            .add(WorkSchedule.workDuration + WorkSchedule.checkoutGrace)) &&
        ModalRoute.of(context)?.isCurrent == true) {
      loggingOut = true;
      logout();
      return;
    }
    if (started &&
        !complete &&
        !awaitingSave &&
        !saving &&
        scheduleAnchor != null &&
        !DateTime.now()
            .isBefore(scheduleAnchor!.add(WorkSchedule.workDuration))) {
      autoFinish();
      return;
    }
    if (started &&
        promptPending &&
        !saving &&
        restUntil == null &&
        (stepSchedule == null || !DateTime.now().isBefore(stepSchedule!))) {
      promptPending = false;
      stepStartedAt = DateTime.now();
      readPrompt();
    }
    if (!started &&
        !loading &&
        error == null &&
        work!.steps.isNotEmpty &&
        plannedStart != null &&
        !DateTime.now().isBefore(plannedStart!) &&
        DateTime.now().isBefore(plannedStart!.add(WorkSchedule.workDuration))) {
      start();
    }
    if (started &&
        !complete &&
        !awaitingSave &&
        !saving &&
        restUntil == null &&
        !enteringRest &&
        scheduleAnchor != null) {
      final window = WorkSchedule.restAt(scheduleAnchor!, DateTime.now(),
          work!.workMinutes ?? 0, work!.restMinutes ?? 0);
      if (window != null) {
        enteringRest = true;
        beginScheduledRest(window);
      }
    }
    if (restUntil != null && !DateTime.now().isBefore(restUntil!)) endRest();
    if (mounted) setState(() {});
  }

  void start() {
    if (plannedStart != null &&
        !DateTime.now()
            .isBefore(plannedStart!.add(WorkSchedule.workDuration))) {
      notice('예정된 작업 시간이 끝났습니다.');
      return;
    }
    setState(() {
      started = true;
      startedAt = DateTime.now();
      stepStartedAt = startedAt;
      scheduleAnchor = WorkSchedule.timeOnDay(
              work!.steps.first.startTime ?? work!.startTime, startedAt!) ??
          startedAt;
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    readPrompt();
  }

  String clock(int seconds) {
    final n = seconds < 0 ? 0 : seconds;
    return '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  }

  Future<void> readPrompt() async {
    if (stepSchedule != null && DateTime.now().isBefore(stepSchedule!)) {
      promptPending = true;
      return;
    }
    try {
      await tts.speak(prompt);
    } catch (_) {
      notice('읽어주기를 시작하지 못했습니다.');
    }
  }

  Future<void> showDevice() async {
    final device = await TokenStorageService().device();
    if (!mounted) return;
    final partner = (device['company_device_name'] ?? '').toString().trim();
    final kioskId = (device['kiosk_id'] ?? '').toString().trim();
    if (partner.isEmpty || kioskId.isEmpty) {
      notice('배정된 기기가 없습니다.');
      return;
    }
    await stopAudio();
    if (!mounted) return;
    try {
      final response = await api.kioskInfo(partner);
      final kiosks = response['kiosks'];
      if (kiosks is! List) throw ApiFailure('기기 현황을 불러오지 못했습니다.');
      final matches = kiosks
          .whereType<Map>()
          .where((k) => k['kioskId'].toString() == kioskId)
          .toList();
      if (matches.isEmpty) throw ApiFailure('배정된 기기를 찾을 수 없습니다.');
      final kiosk = matches.first;
      final current = integer(kiosk['currentCapacity']);
      final max = integer(kiosk['maxCapacity']);
      final rawAvailable = kiosk['isAvailable'];
      final bool? available = rawAvailable == true || rawAvailable == 1
          ? true
          : rawAvailable == false || rawAvailable == 0
              ? false
              : null;
      final status = available == null
          ? '상태 미확인'
          : !available
              ? '사용 불가'
              : current == null || max == null
                  ? '상태 미확인'
                  : current >= max
                      ? '가득참'
                      : current == 0
                          ? '비어있음'
                          : '사용중';
      final name = (kiosk['name'] ?? partner).toString();
      if (started && !complete && !awaitingSave && available != null) {
        deviceChecks.add({
          'type': 'device_check',
          'device_name': name,
          '기기상태체크': status,
          '시간': formatDateTime(DateTime.now()),
          'isAvailable': available
        });
      }
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(name),
                  content: Text('$status\n${current ?? '-'} / ${max ?? '-'}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기'))
                  ]));
    } catch (e) {
      notice(e is ApiFailure ? e.message : '기기 현황을 불러오지 못했습니다.');
    }
  }

  void notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> stopAudio() async {
    await speech.stop();
    await tts.stop();
    if (mounted) setState(() => listening = false);
  }

  Future<void> toggleSpeech() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    await tts.stop();
    try {
      final ok = await speech.listen((text) {
        if (!mounted || !listening || restUntil != null || saving || complete) {
          return;
        }
        final normalized = text.replaceAll(RegExp(r'\s'), '');
        if (['네', '예', '응', '다음', '아니요', '아니오'].contains(normalized)) {
          setState(() => listening = false);
          answer(!['아니요', '아니오'].contains(normalized), recognized: text);
        }
      });
      if (!mounted) return;
      setState(() => listening = ok);
      if (!ok) notice('음성 인식 권한과 기기 지원 여부를 확인해 주세요.');
    } catch (_) {
      notice('음성 인식을 시작하지 못했습니다.');
    }
  }

  Future<void> autoFinish() async {
    if (saving || awaitingSave || complete) return;
    setState(() {
      saving = true;
      awaitingSave = true;
      automaticEnd = true;
    });
    try {
      await stopAudio();
    } catch (_) {}
    if (!mounted) return;
    if (restUntil != null) endRest();
    final end = scheduleAnchor!.add(WorkSchedule.workDuration);
    for (final item in work!.steps) {
      if (answers.any((a) => a['step_id'] == item.id)) continue;
      final planned =
          WorkSchedule.timeOnDay(item.startTime, startedAt!) ?? startedAt!;
      final start = planned.isAfter(end) ? end : planned;
      answers.add({
        'step_id': item.id,
        'display_order': item.order,
        'step_name': item.name,
        'answer': 'auto_completed',
        'answer_label': '자동 종료',
        'work_seconds': item.workSeconds,
        'started_at': start.toIso8601String(),
        'ended_at': end.toIso8601String()
      });
    }
    await finish();
  }

  void videoFinished(bool success) {
    final currentIndex = index;
    if (stepSchedule != null && DateTime.now().isBefore(stepSchedule!)) return;
    final remaining =
        step.workSeconds - DateTime.now().difference(stepStartedAt!).inSeconds;
    videoCompletionTimer?.cancel();
    videoCompletionTimer =
        Timer(Duration(seconds: remaining > 0 ? remaining : 0), () {
      if (mounted &&
          index == currentIndex &&
          !awaitingSave &&
          !complete &&
          restUntil == null) {
        answer(success, outcome: success ? 'video_completed' : 'video_error');
      }
    });
  }

  Future<void> answer(bool yes, {String? outcome, String? recognized}) async {
    if (saving || complete || awaitingSave || restUntil != null) return;
    final remaining =
        step.workSeconds - DateTime.now().difference(stepStartedAt!).inSeconds;
    if (remaining > 0) {
      notice('작업 시간이 ${clock(remaining)} 남았습니다.');
      return;
    }
    setState(() => saving = true);
    try {
      await stopAudio();
      if (!mounted) return;
      answers.add({
        'step_id': step.id,
        'step_name': step.name,
        'question': prompt,
        'recognized_text': recognized,
        'answer': outcome ?? (yes ? 'yes' : 'no'),
        'display_order': step.order,
        'work_seconds': step.workSeconds,
        'video_path': step.videoPath,
        'ended_at': DateTime.now().toIso8601String(),
        'answer_label': yes ? '예' : '아니요',
        'answered_at': DateTime.now().toIso8601String(),
        'started_at': stepStartedAt?.toIso8601String()
      });
      if (questionIndex + 1 < step.questions.length) {
        setState(() => questionIndex++);
      } else if (index + 1 < work!.steps.length) {
        setState(() {
          index++;
          questionIndex = 0;
          stepStartedAt = DateTime.now();
        });
      } else {
        setState(() => awaitingSave = true);
        await finish();
        return;
      }
      await readPrompt();
    } catch (_) {
      notice('답변 처리를 완료하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> finish() async {
    if (complete || pendingRecord?['server_submitted'] == true) return;
    setState(() => saving = true);
    try {
      final id = await TokenStorageService().userId();
      if (id == null) throw ApiFailure('다시 로그인해 주세요.');
      final now = automaticEnd
          ? scheduleAnchor!.add(WorkSchedule.workDuration)
          : DateTime.now();
      if (pendingRecord == null) {
        final payload = WorkResultPayload(
            work: work!,
            userId: id,
            start: startedAt!,
            end: now,
            restSeconds: restSeconds,
            answers: answers,
            deviceChecks: deviceChecks);
        pendingRecord = {
          'record_id': payload.request['packetid'],
          'work_id': work!.id,
          'work_name': work!.name,
          'started_at': startedAt!.toIso8601String(),
          'ended_at': now.toIso8601String(),
          'answers': List.of(answers),
          'request': payload.request,
          'server_submitted': false
        };
      }
      await logs.save(id, pendingRecord!);
      final resultId = await api.submitWorkResult(
          Map<String, dynamic>.from(pendingRecord!['request'] as Map));
      pendingRecord!['server_submitted'] = true;
      pendingRecord!['result_id'] = resultId;
      // Server success is retained even if updating the local history fails.
      try {
        await logs.save(id, pendingRecord!);
      } catch (_) {
        notice('서버에 저장됐지만 기기 내 기록 갱신에 실패했습니다.');
      }
      if (!mounted) return;
      setState(() => complete = true);
    } catch (e) {
      notice(
          e is ApiFailure ? e.message : '결과 저장에 실패했습니다. 기록에서 다시 전송할 수 있습니다.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> beginScheduledRest(RestWindow window) async {
    try {
      await stopAudio();
      if (!mounted) return;
      setState(() {
        restStartedAt = DateTime.now();
        restUntil = window.end;
      });
    } finally {
      enteringRest = false;
    }
  }

  void endRest() {
    final began = restStartedAt;
    final until = restUntil;
    if (began == null || until == null) return;
    final now = DateTime.now();
    final end = now.isAfter(until) ? until : now;
    final seconds = end.difference(began).inSeconds;
    restSeconds += seconds;
    answers.add({
      'step_id': 0,
      'step_name': '휴식',
      'answer': 'rest',
      'answer_label': '휴식',
      'started_at': began.toIso8601String(),
      'ended_at': end.toIso8601String(),
      'work_seconds': seconds
    });
    stepStartedAt = stepStartedAt?.add(Duration(seconds: seconds));
    setState(() {
      restStartedAt = null;
      restUntil = null;
    });
  }

  Future<void> logout() async {
    if (started && !complete) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('작업을 중단할까요?'),
                  content: const Text('진행 중인 답변은 저장되지 않습니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('계속하기')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('로그아웃'))
                  ]));
      if (ok != true) return;
    }
    try {
      await stopAudio();
      try {
        await api.logout();
      } catch (_) {
        notice('서버 로그아웃을 확인하지 못했지만 기기에서 로그아웃했습니다.');
      }
      if (mounted) {
        setState(() => started = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      notice('로그아웃에 실패했습니다.');
    }
  }

  Widget content() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!),
        const SizedBox(height: 16),
        FilledButton(onPressed: load, child: const Text('다시 시도'))
      ]));
    }
    final info = work!;
    if (complete) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, size: 72),
        const SizedBox(height: 16),
        const Text('서버에 작업 결과를 저장했습니다.'),
        TextButton(
            onPressed: saving || awaitingSave
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const ResultLogScreen())),
            child: const Text('작업 기록 보기'))
      ]));
    }
    if (!started) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(info.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (info.startTime != null) Text('시작: ${info.startTime}'),
        if (info.endTime != null) Text('종료: ${info.endTime}'),
        if (info.workMinutes != null) Text('기준 작업 시간: ${info.workMinutes}분'),
        if (info.restMinutes != null) Text('기준 휴식 시간: ${info.restMinutes}분'),
        const SizedBox(height: 24),
        if (info.steps.isEmpty)
          const Text('진행할 작업 단계가 없습니다.')
        else
          FilledButton(
              onPressed:
                  plannedStart != null && DateTime.now().isBefore(plannedStart!)
                      ? null
                      : start,
              child: const Text('작업 시작')),
        if (plannedStart != null && DateTime.now().isBefore(plannedStart!))
          Text(
              '작업 시작까지 ${clock(plannedStart!.difference(DateTime.now()).inSeconds)}'),
      ]);
    }
    if (restUntil != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('휴식 중'),
        Text(clock(restUntil!.difference(DateTime.now()).inSeconds),
            style: Theme.of(context).textTheme.displayLarge),
      ]));
    }
    final stepAt = stepSchedule;
    if (stepAt != null && DateTime.now().isBefore(stepAt)) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${step.name} 시작 대기'),
        Text(clock(stepAt.difference(DateTime.now()).inSeconds),
            style: Theme.of(context).textTheme.displayMedium)
      ]));
    }
    final elapsed =
        DateTime.now().difference(startedAt!).inSeconds - restSeconds;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(info.name, style: Theme.of(context).textTheme.headlineSmall),
      Text('작업 ${index + 1} / ${info.steps.length} · 경과 ${clock(elapsed)}'),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: index / info.steps.length),
      const SizedBox(height: 24),
      Text(step.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      if (step.videoPath != null && step.videoPath!.isNotEmpty)
        WorkVideo(
            key: ValueKey('${step.id}-$index'),
            source: step.videoPath!,
            onFinished: videoFinished)
      else
        Image.asset('assets/images/chr_rab.png',
            height: 160, fit: BoxFit.contain),
      const SizedBox(height: 16),
      Text(prompt, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Wrap(spacing: 12, children: [
        OutlinedButton.icon(
            onPressed: readPrompt,
            icon: const Icon(Icons.volume_up),
            label: const Text('다시 듣기')),
        OutlinedButton.icon(
            onPressed: saving || awaitingSave ? null : toggleSpeech,
            icon: Icon(listening ? Icons.mic : Icons.mic_none),
            label: Text(listening ? '음성 인식 끄기' : '음성 답변'))
      ]),
      const SizedBox(height: 24),
      if (step.videoPath == null || step.videoPath!.isEmpty)
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed:
                      saving || awaitingSave ? null : () => answer(false),
                  child: const Text('아니요'))),
          const SizedBox(width: 16),
          Expanded(
              child: FilledButton(
                  onPressed: saving || awaitingSave ? null : () => answer(true),
                  child: const Text('네')))
        ]),
      if (awaitingSave)
        TextButton(
            onPressed: saving ? null : finish,
            child: const Text('결과 저장 다시 시도')),
    ]);
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !started || complete,
      child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('수호천사'),
              actions: [
                IconButton(
                    tooltip: '기기 상태',
                    onPressed: saving || awaitingSave ? null : showDevice,
                    icon: const Icon(Icons.devices)),
                IconButton(
                    tooltip: '작업 기록',
                    onPressed: saving || awaitingSave
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const ResultLogScreen())),
                    icon: const Icon(Icons.history)),
                IconButton(
                    tooltip: '로그아웃',
                    onPressed: saving ? null : logout,
                    icon: const Icon(Icons.logout))
              ]),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: content())))));
}
