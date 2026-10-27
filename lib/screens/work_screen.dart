import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../theme/appearance_scope.dart';
import '../models/work_info.dart';
import '../models/work_result.dart';
import '../models/work_schedule.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/work_log_service.dart';
import '../services/work_draft_service.dart';
import '../services/result_submission_service.dart';
import '../widgets/work_video.dart';
import '../widgets/work_message.dart';
import '../widgets/question_panel.dart';
import '../widgets/kiosk_status_dialog.dart';
import '../widgets/completion_panel.dart';
import 'result_log_screen.dart';
import 'community_screen.dart';
import 'device_history_screen.dart';
import '../services/device_history_service.dart';
import 'passkey_screen.dart';
import '../services/passkey_service.dart';
import '../services/app_preferences.dart';

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
  final drafts = WorkDraftService();
  int? sessionUser;
  String? displayName;
  DateTime? lastCheckpoint;
  bool draftWarning = false;
  WorkInfo? work;
  String? error;
  bool autoLoginEnabled = true;
  WorkStatusResponse? workStatus;
  bool loading = true,
      started = false,
      saving = false,
      listening = false,
      complete = false,
      awaitingSave = false;
  int index = 0, questionIndex = 0;
  DateTime? startedAt, stepStartedAt, restStartedAt, restUntil;
  int restSeconds = 0, stepRestSeconds = 0;
  bool foreground = true, submitting = false;
  bool? pendingVideoResult;
  bool speaking = false;
  int mediaBlocks = 0;
  bool get mediaBlocked => mediaBlocks > 0;
  bool speechUnavailable = false, speechEnabled = true;
  void holdMedia() {
    if (mounted) setState(() => mediaBlocks++);
  }

  void releaseMedia() {
    if (mounted) {
      setState(() {
        if (mediaBlocks > 0) mediaBlocks--;
      });
    }
  }

  final preferences = AppPreferences();
  late final DeviceMonitor deviceMonitor;
  int promptReadGeneration = 0;
  bool checkedOut = false, checkingOut = false, checkoutConfirmed = false;
  List<Map<String, dynamic>> completedHistory = [];
  final answers = <Map<String, dynamic>>[];
  final deviceChecks = <Map<String, dynamic>>[];
  Map<String, dynamic>? pendingRecord;
  DateTime? scheduleAnchor, plannedStart;
  bool enteringRest = false, promptPending = false, automaticEnd = false;
  DateTime? get stepSchedule =>
      started ? WorkSchedule.timeOnDay(step.startTime, startedAt!) : null;
  Timer? timer;
  int get remainingSeconds =>
      step.workSeconds -
      DateTime.now().difference(stepStartedAt!).inSeconds +
      stepRestSeconds;
  WorkStep get step => work!.steps[index];
  String get prompt =>
      step.questions.isEmpty ? step.prompt : step.questions[questionIndex];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    deviceMonitor = DeviceMonitor(
        fetch: fetchDeviceReading, history: DeviceHistoryService());
    speech.onListeningChanged = (value) {
      if (mounted) setState(() => listening = value);
    };
    tts.onSpeakingChanged = (value) {
      if (mounted) setState(() => speaking = value);
    };
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    deviceMonitor.dispose();
    tts.onSpeakingChanged = null;
    speech.onListeningChanged = null;
    unawaited(stopAudio());
    api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      unawaited(stopAudio());
      unawaited(checkpoint());
      if (mounted) setState(() => listening = false);
    } else if (mounted) {
      tick();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      workStatus = null;
    });
    try {
      speechEnabled = await preferences.speechEnabled();
      autoLoginEnabled = await preferences.autoLoginEnabled();
      sessionUser = await api.tokens.userId();
      final profile = await api.tokens.device();
      displayName =
          profile['name'] is String ? profile['name'] as String : null;
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
        if (!await restoreCompletion()) await restoreDraft();
      }
    } on WorkStatusResponse catch (status) {
      if (mounted) {
        setState(() => workStatus = status);
        // A status response can still carry the original assignment. Restore
        // completion only with the existing same-account/day/assignment receipt.
        final raw = status.response;
        if (raw['work'] is Map<String, dynamic>) {
          WorkInfo? assignment;
          try {
            assignment = WorkInfo.fromJson(raw);
          } on FormatException {
            // Partial schedule data is still useful for the summary below.
          }
          if (assignment != null) {
            work = assignment;
            try {
              await restoreCompletion();
            } on ApiFailure catch (e) {
              if (mounted) notice(e.message);
            }
          }
        }
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

  Future<void> checkpoint() async {
    if (work == null || !started || complete || sessionUser == null) return;
    lastCheckpoint = DateTime.now();
    try {
      await drafts.save(sessionUser!, work!, {
        'index': index,
        'question_index': questionIndex,
        'started_at': startedAt!.toIso8601String(),
        'step_started_at': stepStartedAt!.toIso8601String(),
        'schedule_anchor': scheduleAnchor!.toIso8601String(),
        'rest_started_at': restStartedAt?.toIso8601String(),
        'rest_until': restUntil?.toIso8601String(),
        'rest_seconds': restSeconds,
        'step_rest_seconds': stepRestSeconds,
        'answers': answers,
        'device_checks': deviceChecks,
        'pending_record': pendingRecord,
        'awaiting_save': awaitingSave,
        'prompt_pending': promptPending,
        'automatic_end': automaticEnd,
        'video_result': pendingVideoResult,
      });
      draftWarning = false;
    } catch (_) {
      if (!draftWarning) notice('기기 내 자동 저장에 실패했습니다. 창을 닫기 전에 작업을 완료해 주세요.');
      draftWarning = true;
    }
  }

  Future<bool> restoreCompletion() async {
    if (sessionUser == null) return false;
    try {
      final record = await logs.completedAssignment(
          sessionUser!, drafts.signature(work!), DateTime.now());
      if (record == null || !mounted) return false;
      setState(() {
        pendingRecord = record;
        startedAt = DateTime.parse(record['started_at'] as String);
        complete = true;
        started = false;
        awaitingSave = false;
      });
      return true;
    } catch (_) {
      throw ApiFailure('완료 기록을 확인하지 못했습니다. 기기 저장 공간을 확인한 뒤 다시 시도해 주세요.');
    }
  }

  Future<void> restoreDraft() async {
    if (sessionUser == null || work!.steps.isEmpty) return;
    Map<String, dynamic>? state;
    try {
      state = await drafts.load(sessionUser!, work!);
    } catch (_) {
      notice('이전 작업의 자동 저장을 확인하지 못했습니다.');
      return;
    }
    if (state == null || !mounted) return;
    final restored = state;
    setState(() {
      index = restored['index'] as int;
      questionIndex = restored['question_index'] as int;
      startedAt = DateTime.parse(restored['started_at'] as String);
      stepStartedAt = DateTime.parse(restored['step_started_at'] as String);
      scheduleAnchor = DateTime.parse(restored['schedule_anchor'] as String);
      restStartedAt =
          DateTime.tryParse(restored['rest_started_at']?.toString() ?? '');
      restUntil = DateTime.tryParse(restored['rest_until']?.toString() ?? '');
      restSeconds = restored['rest_seconds'] as int;
      stepRestSeconds = restored['step_rest_seconds'] as int;
      answers
          .addAll((restored['answers'] as List).cast<Map<String, dynamic>>());
      deviceChecks.addAll(
          (restored['device_checks'] as List).cast<Map<String, dynamic>>());
      pendingRecord = restored['pending_record'] as Map<String, dynamic>?;
      awaitingSave = restored['awaiting_save'] == true || pendingRecord != null;
      promptPending = restored['prompt_pending'] == true;
      automaticEnd = restored['automatic_end'] == true;
      pendingVideoResult = restored['video_result'] is bool
          ? restored['video_result'] as bool
          : null;
      started = true;
    });
    notice(awaitingSave
        ? '저장 대기 중인 작업을 복구했습니다. 결과 저장을 확인해 주세요.'
        : '진행 중이던 작업을 복구했습니다.');
  }

  void tick() {
    if (!mounted || !foreground) return;
    if (!loading && sessionUser != null && !checkedOut && !checkingOut) {
      unawaited(pollDevice(announce: deviceMonitor.lastAttempt != null));
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
        !complete &&
        !awaitingSave &&
        !saving &&
        restUntil == null &&
        (stepSchedule == null || !DateTime.now().isBefore(stepSchedule!))) {
      promptPending = false;
      stepStartedAt = DateTime.now();
      readPrompt();
    }
    if (!started &&
        !complete &&
        !loading &&
        error == null &&
        workStatus == null &&
        work != null &&
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
    if (pendingVideoResult == true &&
        foreground &&
        !mediaBlocked &&
        started &&
        !saving &&
        !enteringRest &&
        !complete &&
        !awaitingSave &&
        restUntil == null &&
        !promptPending &&
        remainingSeconds <= 0) {
      final result = pendingVideoResult!;
      pendingVideoResult = null;
      unawaited(
          answer(result, outcome: result ? 'video_completed' : 'video_error'));
    }
    if (started &&
        !complete &&
        !saving &&
        (lastCheckpoint == null ||
            DateTime.now().difference(lastCheckpoint!).inSeconds >= 10)) {
      unawaited(checkpoint());
    }
    if (mounted) setState(() {});
  }

  void start() {
    if (workStatus != null || work == null || work!.steps.isEmpty) return;
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
    unawaited(checkpoint());
    readPrompt();
  }

  String clock(int seconds) {
    final n = seconds < 0 ? 0 : seconds;
    return '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  }

  Future<void> readPrompt({bool manual = false}) async {
    if (stepSchedule != null && DateTime.now().isBefore(stepSchedule!)) {
      promptPending = true;
      return;
    }
    if (!speechEnabled && !manual) return;
    final request = ++promptReadGeneration;
    final text = prompt;
    try {
      await speech.stop();
      if (!mounted ||
          request != promptReadGeneration ||
          !started ||
          complete ||
          awaitingSave) {
        return;
      }
      setState(() => listening = false);
      await tts.speak(text);
    } catch (e) {
      if (request == promptReadGeneration) {
        notice(e is TtsFailure ? e.message : '읽어주기를 시작하지 못했습니다.');
      }
    }
  }

  Future<DeviceReading?> fetchDeviceReading() async {
    final userId = await api.tokens.userId();
    if (userId == null || checkedOut) return null;
    final device = await api.tokens.device();
    final partner = (device['company_device_name'] ?? '').toString().trim();
    final kiosk = (device['kiosk_id'] ?? '').toString().trim();
    if (partner.isEmpty || kiosk.isEmpty) return null;
    final at = DateTime.now();
    try {
      final response = await api.kioskInfo(partner);
      final values = response['kiosks'];
      if (values is! List) throw ApiFailure('수거기 현황을 불러오지 못했습니다.');
      final matches = values
          .whereType<Map>()
          .where((r) => r['kioskId'].toString() == kiosk)
          .toList();
      if (matches.isEmpty) throw ApiFailure('배정된 수거기를 찾을 수 없습니다.');
      final data = matches.first;
      final raw = data['isAvailable'];
      return DeviceReading(
          userId: userId,
          partner: partner,
          kiosk: kiosk,
          name: '${data['name'] ?? partner}',
          at: at,
          current: num.tryParse('${data['currentCapacity']}'),
          capacity: num.tryParse('${data['maxCapacity']}'),
          available: raw == true || raw == 1
              ? true
              : raw == false || raw == 0
                  ? false
                  : null);
    } catch (e) {
      return DeviceReading(
          userId: userId,
          partner: partner,
          kiosk: kiosk,
          name: partner,
          at: at,
          error: e is ApiFailure ? e.message : '수거기 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> pollDevice({bool force = false, bool announce = true}) async {
    if (!mounted || checkedOut || checkingOut) return;
    try {
      final reading =
          await deviceMonitor.poll(force: force, foreground: foreground);
      if (!mounted || checkedOut || reading == null || !announce) return;
      notice(reading.error != null
          ? '페트병 수거기 상태를 확인하지 못했습니다.'
          : '${reading.name} 적재율 ${reading.percentLabel}${reading.available == false ? ' · 사용 불가' : ''}');
      if (deviceMonitor.storageFailed) notice('수거기 조회 결과를 기기에 저장하지 못했습니다.');
    } catch (_) {
      if (mounted && announce && !checkedOut) notice('수거기 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> showDeviceHistory() async {
    final user = await api.tokens.userId();
    final device = await api.tokens.device();
    final partner = (device['company_device_name'] ?? '').toString().trim();
    final kiosk = (device['kiosk_id'] ?? '').toString().trim();
    if (!mounted) return;
    if (user == null || partner.isEmpty || kiosk.isEmpty || checkedOut) {
      notice('로그인한 계정에 배정된 수거기가 없습니다.');
      return;
    }
    holdMedia();
    await stopAudio();
    if (!mounted) return;
    try {
      await pollDevice(announce: false);
      if (!mounted) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => DeviceHistoryScreen(
                  monitor: deviceMonitor,
                  userId: user,
                  partner: partner,
                  kiosk: kiosk,
                  onRefresh: () => pollDevice(force: true))));
    } finally {
      if (mounted) releaseMedia();
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
              : current == null || max == null || current < 0 || max <= 0
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
      holdMedia();
      try {
        await showDialog<void>(
            context: context,
            builder: (context) => KioskStatusDialog(
                name: name,
                status: status,
                current: current,
                capacity: max,
                onHistory: () {
                  Navigator.pop(context);
                  showDeviceHistory();
                }));
      } finally {
        if (mounted) releaseMedia();
      }
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
    promptReadGeneration++;
    await Future.wait([
      (() async {
        try {
          await speech.stop().timeout(const Duration(seconds: 3));
        } catch (_) {}
      })(),
      (() async {
        try {
          await tts.stop().timeout(const Duration(seconds: 3));
        } catch (_) {}
      })(),
    ]);
    if (mounted) setState(() => listening = false);
  }

  Future<void> toggleSpeech() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    promptReadGeneration++;
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
      setState(() {
        listening = ok;
        speechUnavailable = !ok;
      });
      if (!ok) notice('음성 인식 권한과 기기 지원 여부를 확인해 주세요.');
    } catch (_) {
      if (mounted) setState(() => speechUnavailable = true);
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
    if (!mounted || !started || complete || awaitingSave) return;
    pendingVideoResult = pendingVideoResult == true || success;
    unawaited(checkpoint());
    tick();
  }

  Future<void> answer(bool yes, {String? outcome, String? recognized}) async {
    if (!foreground ||
        saving ||
        complete ||
        awaitingSave ||
        restUntil != null ||
        enteringRest ||
        promptPending) {
      return;
    }
    final remaining = remainingSeconds;
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
        setState(() {
          questionIndex++;
          pendingVideoResult = null;
        });
      } else if (index + 1 < work!.steps.length) {
        setState(() {
          pendingVideoResult = null;
          stepRestSeconds = 0;
          index++;
          questionIndex = 0;
          stepStartedAt = DateTime.now();
        });
      } else {
        setState(() => awaitingSave = true);
        await finish();
        return;
      }
      await checkpoint();
      await readPrompt();
    } catch (_) {
      notice('답변 처리를 완료하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> finish() async {
    if (submitting || complete || pendingRecord?['server_submitted'] == true) {
      return;
    }
    submitting = true;
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
          'assignment_signature': drafts.signature(work!),
          'work_id': work!.id,
          'work_name': work!.name,
          'started_at': startedAt!.toIso8601String(),
          'ended_at': now.toIso8601String(),
          'answers': List.of(answers),
          'request': payload.request,
          'server_submitted': false
        };
      }
      await checkpoint();
      final outcome =
          await ResultSubmissionService(api, logs).send(id, pendingRecord!);
      pendingRecord!['server_submitted'] = true;
      pendingRecord!['result_id'] = outcome.resultId;
      if (!outcome.persistedLocally) {
        notice('서버에 저장됐지만 기기 내 기록 갱신에 실패했습니다.');
      }
      if (!mounted) return;
      setState(() {
        complete = true;
        awaitingSave = false;
      });
      try {
        await drafts.clear(id);
      } catch (_) {}
    } catch (e) {
      notice(
          e is ApiFailure ? e.message : '결과 저장에 실패했습니다. 기록에서 다시 전송할 수 있습니다.');
    } finally {
      submitting = false;
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> beginScheduledRest(RestWindow window) async {
    try {
      await stopAudio();
      if (!mounted || !DateTime.now().isBefore(window.end)) return;
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
    stepRestSeconds += seconds;
    setState(() {
      restStartedAt = null;
      restUntil = null;
    });
  }

  Future<void> lockApp() async {
    if (saving) return;
    await checkpoint();
    await stopAudio();
    if (!mounted) return;
    PasskeyService().lock();
    setState(() => started = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> checkout() async {
    if (checkingOut || checkedOut || (!complete && workStatus == null)) return;
    setState(() => checkingOut = true);
    try {
      try {
        completedHistory =
            sessionUser == null ? [] : await logs.load(sessionUser!);
      } catch (_) {
        completedHistory = pendingRecord == null ? [] : [pendingRecord!];
      }
      await stopAudio();
      try {
        await api.logout();
        checkoutConfirmed = true;
      } catch (_) {
        checkoutConfirmed = false;
        notice('기기에서 퇴근 처리했습니다. 서버 로그아웃은 확인하지 못했습니다.');
      }
      if (!mounted) return;
      setState(() {
        checkedOut = true;
        checkingOut = false;
        started = false;
      });
    } finally {
      if (mounted && checkingOut) setState(() => checkingOut = false);
    }
  }

  Future<void> logout() async {
    if (started && !complete) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('작업을 중단할까요?'),
                  content: const Text(
                      '현재 진행 상태는 기기에 보관됩니다. 같은 계정으로 다시 로그인하면 이어서 진행할 수 있습니다.'),
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
      await checkpoint();
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

  DateTime? get reentryStart {
    final raw = workStatus?.response['work'];
    if (raw is! Map) return null;
    return WorkSchedule.timeOnDay(
        raw['auto_start_time']?.toString(), DateTime.now());
  }

  DateTime? get reentryEnd {
    final raw = workStatus?.response['work'];
    if (raw is! Map) return null;
    // Only display a time actually supplied by the server. Missing schedule
    // information must never silently turn into the screenshot's 09:00/12:00.
    return WorkSchedule.timeOnDay(raw['end_time']?.toString(), DateTime.now());
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
    if (complete || workStatus != null) {
      return CompletionPanel(
        name: displayName,
        scheduled: !complete,
        start: complete ? startedAt : reentryStart,
        end: complete
            ? DateTime.tryParse(pendingRecord?['ended_at']?.toString() ?? '')
            : reentryEnd,
        onDevice: checkedOut || checkingOut ? null : showDevice,
        onCommunity: checkedOut || checkingOut ? null : showCommunity,
        onHistory: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => ResultLogScreen(
                    readOnlyRecords: checkedOut ? completedHistory : null))),
        onCheckout: saving || checkingOut || checkedOut ? null : checkout,
        checkoutLabel: checkingOut
            ? '퇴근 처리 중…'
            : checkedOut
                ? (checkoutConfirmed ? '퇴근 완료' : '퇴근 완료 · 서버 확인 필요')
                : '퇴근하기',
      );
    }
    final info = work!;
    if (!started) {
      return WorkMessage(title: '안녕하세요!', children: [
        Text(info.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5A83A7), fontSize: 24)),
        const SizedBox(height: 16),
        if (info.startTime != null)
          Text('시작: ${info.startTime}', textAlign: TextAlign.center),
        if (info.endTime != null)
          Text('종료: ${info.endTime}', textAlign: TextAlign.center),
        if (info.workMinutes != null)
          Text('기준 작업 시간: ${info.workMinutes}분', textAlign: TextAlign.center),
        if (info.restMinutes != null)
          Text('기준 휴식 시간: ${info.restMinutes}분', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (info.steps.isEmpty)
          const Text('진행할 작업 단계가 없습니다.', textAlign: TextAlign.center)
        else
          FilledButton(
              onPressed:
                  plannedStart != null && DateTime.now().isBefore(plannedStart!)
                      ? null
                      : start,
              child: const Text('작업 시작')),
        if (plannedStart != null && DateTime.now().isBefore(plannedStart!))
          Text(
              '작업 시작까지 ${clock(plannedStart!.difference(DateTime.now()).inSeconds)}',
              textAlign: TextAlign.center),
      ]);
    }
    if (awaitingSave) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_upload_outlined, size: 64),
                const SizedBox(height: 16),
                const Text('작업이 끝났습니다. 서버 저장을 확인해 주세요.'),
                const SizedBox(height: 12),
                const Text('응답을 받지 못했다면 이미 저장됐을 수 있습니다. 서버 기록 확인 후 다시 전송하세요.'),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: saving ? null : finish,
                    child: Text(saving ? '저장 확인 중…' : '결과 저장 다시 시도')),
              ])));
    }
    if (restUntil != null) {
      return WorkMessage(title: '휴식 중', children: [
        const Text('편하게 쉬고 오세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5A83A7), fontSize: 24)),
        const SizedBox(height: 16),
        Text(clock(restUntil!.difference(DateTime.now()).inSeconds),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium),
      ]);
    }
    final stepAt = stepSchedule;
    if (stepAt != null && DateTime.now().isBefore(stepAt)) {
      return WorkMessage(title: '${step.name} 시작 대기', children: [
        Text(clock(stepAt.difference(DateTime.now()).inSeconds),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium)
      ]);
    }
    if (questionVisible) {
      final total = info.steps.fold<int>(
          0,
          (sum, item) =>
              sum + (item.questions.isEmpty ? 1 : item.questions.length));
      final current = info.steps.take(index).fold<int>(
              0,
              (sum, item) =>
                  sum + (item.questions.isEmpty ? 1 : item.questions.length)) +
          questionIndex +
          1;
      return QuestionPanel(
          prompt: prompt,
          current: current,
          total: total,
          speaking: speaking,
          listening: listening,
          media: step.videoPath != null && step.videoPath!.isNotEmpty
              ? WorkVideo(
                  key: ValueKey('${step.id}-$index-$questionIndex'),
                  source: step.videoPath!,
                  onFinished: videoFinished,
                  paused: mediaBlocked || speaking || listening,
                  onRetry: () => setState(() => pendingVideoResult = null))
              : null,
          mediaStatus: pendingVideoResult == false
              ? '영상 재생을 다시 시도해 주세요.'
              : pendingVideoResult == true
                  ? '시청 완료 · 다음 단계까지 ${clock(remainingSeconds)}'
                  : '영상을 시청해 주세요.',
          speechUnavailable: speechUnavailable,
          onReplay: () => readPrompt(manual: true),
          onSpeech: toggleSpeech,
          onYes: saving ? null : () => answer(true),
          onNo: saving ? null : () => answer(false),
          onSettings: showSettings,
          onDevice: showDevice);
    }
    return const Center(child: Text('작업 상태를 확인하고 있습니다.'));
  }

  bool get questionVisible =>
      work != null &&
      started &&
      !complete &&
      !awaitingSave &&
      restUntil == null &&
      (stepSchedule == null || !DateTime.now().isBefore(stepSchedule!));

  Future<void> showCommunity() async {
    holdMedia();
    await stopAudio();
    if (!mounted) return;
    try {
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (_) => const CommunityScreen()));
    } finally {
      if (mounted) releaseMedia();
    }
  }

  void showSettings() {
    holdMedia();
    unawaited(stopAudio());
    var preferenceSaving = false;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: (AppStyle.isBeta(context)
            ? const Color(0xF0FFFFFF)
            : const Color(0xFFF2F2F2)),
        builder: (sheet) => StatefulBuilder(
            builder: (sheet, updateSheet) => ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheet).height * .85),
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(children: [
                                const Expanded(
                                    child: Text('설정',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800))),
                                IconButton(
                                    tooltip: '설정 닫기',
                                    onPressed: () => Navigator.pop(sheet),
                                    icon: const Icon(Icons.close)),
                              ])),
                          ListTile(
                              leading: Icon(
                                  AppearanceScope.of(sheet)?.enabled == true
                                      ? Icons.toggle_on
                                      : Icons.toggle_off),
                              title: Text(
                                  AppearanceScope.of(sheet)?.enabled == true
                                      ? '베타버전 끄기'
                                      : '베타버전 켜기'),
                              subtitle: const Text('화면 스타일만 변경합니다.'),
                              enabled:
                                  AppearanceScope.of(sheet)?.saving != true,
                              onTap: () async {
                                final appearance = AppearanceScope.of(sheet);
                                if (appearance == null) return;
                                final saved = await appearance
                                    .setEnabled(!appearance.enabled);
                                if (!saved && mounted) {
                                  notice('화면 설정을 저장하지 못했습니다. 다시 시도해 주세요.');
                                }
                              }),
                          SwitchListTile(
                              title: const Text('자동 로그인'),
                              subtitle:
                                  const Text('앱을 다시 열 때 저장된 세션을 서버에서 확인합니다.'),
                              value: autoLoginEnabled,
                              onChanged: preferenceSaving
                                  ? null
                                  : (value) async {
                                      updateSheet(
                                          () => preferenceSaving = true);
                                      try {
                                        await preferences
                                            .setAutoLoginEnabled(value);
                                        if (mounted) {
                                          setState(
                                              () => autoLoginEnabled = value);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          notice('자동 로그인 설정을 저장하지 못했습니다.');
                                        }
                                      } finally {
                                        if (sheet.mounted) {
                                          updateSheet(
                                              () => preferenceSaving = false);
                                        }
                                      }
                                    }),
                          SwitchListTile(
                              title: const Text('질문 자동 읽기'),
                              subtitle: Text(speechEnabled
                                  ? '질문을 자동으로 읽습니다.'
                                  : '자동 읽기가 꺼져 있습니다.'),
                              value: speechEnabled,
                              onChanged: preferenceSaving
                                  ? null
                                  : (value) async {
                                      updateSheet(
                                          () => preferenceSaving = true);
                                      try {
                                        await preferences
                                            .setSpeechEnabled(value);
                                        if (!mounted) return;
                                        setState(() => speechEnabled = value);
                                        if (!value) await stopAudio();
                                      } catch (_) {
                                        notice(
                                            '음성 설정을 저장하지 못했습니다. 다시 시도해 주세요.');
                                      } finally {
                                        if (sheet.mounted) {
                                          updateSheet(
                                              () => preferenceSaving = false);
                                        }
                                      }
                                    }),
                          if (started && !complete)
                            ListTile(
                                leading: const Icon(Icons.volume_up),
                                title: const Text('현재 질문 다시 듣기'),
                                onTap: () {
                                  Navigator.pop(sheet);
                                  readPrompt(manual: true);
                                }),
                          const Divider(),
                          ListTile(
                              leading: const Icon(Icons.show_chart),
                              title: const Text('기기 기록 · 그래프'),
                              onTap: () {
                                Navigator.pop(sheet);
                                showDeviceHistory();
                              }),
                          ListTile(
                              leading: const Icon(Icons.forum_outlined),
                              title: const Text('커뮤니티'),
                              onTap: () {
                                Navigator.pop(sheet);
                                showCommunity();
                              }),
                          ListTile(
                              leading: const Icon(Icons.key),
                              title: const Text('패스키 로그인 설정'),
                              onTap: () {
                                Navigator.pop(sheet);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => const PasskeyScreen()));
                              }),
                          ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('근무 기록'),
                              onTap: () {
                                Navigator.pop(sheet);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ResultLogScreen()));
                              }),
                          if (PasskeyService().enrolled)
                            ListTile(
                                leading: const Icon(Icons.lock_outline),
                                title: const Text('앱 잠그기'),
                                onTap: () {
                                  Navigator.pop(sheet);
                                  lockApp();
                                }),
                          ListTile(
                              leading: const Icon(Icons.logout),
                              title: const Text('로그아웃'),
                              onTap: () {
                                Navigator.pop(sheet);
                                logout();
                              }),
                          const SizedBox(height: 8),
                          const Text('수호천사 v1.11.0',
                              style: TextStyle(color: Colors.grey)),
                        ])))))).whenComplete(() {
      if (mounted) releaseMedia();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !started || complete,
      child: Scaffold(
          backgroundColor: (AppStyle.isBeta(context)
              ? Colors.transparent
              : const Color(0xFFF2F2F2)),
          appBar: questionVisible || complete || workStatus != null
              ? null
              : AppBar(
                  backgroundColor: (AppStyle.isBeta(context)
                      ? Colors.transparent
                      : const Color(0xFFF2F2F2)),
                  automaticallyImplyLeading: false,
                  title: const Text('수호천사'),
                  actions: [
                      IconButton(
                          tooltip: '커뮤니티',
                          onPressed:
                              saving || awaitingSave ? null : showCommunity,
                          icon: const Icon(Icons.forum_outlined)),
                      if (PasskeyService().enrolled)
                        IconButton(
                            tooltip: '앱 잠그기',
                            onPressed: saving ? null : lockApp,
                            icon: const Icon(Icons.lock_outline)),
                      IconButton(
                          tooltip: '패스키 로그인 설정',
                          onPressed: saving || awaitingSave
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => const PasskeyScreen())),
                          icon: const Icon(Icons.key)),
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
