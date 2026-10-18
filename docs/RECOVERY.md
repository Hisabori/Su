# 복원 근거

대상 APK SHA-256: 557f34845199aa08eca88f928b917e42253b802a861e306c683f97014fcaedaf

B(l)utter를 해당 Dart 3.8.1 런타임과 함께 빌드하여 AOT 메서드, Object Pool, 문자열 및 ARM64 명령을 분석했습니다. 서버의 `/swagger/v1/swagger.json`도 GET으로 확인했으며 `PUT /api/User/{id}` 및 `PUT /api/Admin/{id}` 구조가 있습니다. Swagger의 요청 본문에는 구체적인 필드 스키마가 없어 그 부분은 APK를 근거로 재구성했습니다.

## 주요 근거
- `ApiService.login` 0x428f6c 주변: packetid / username / password, `/api/user/login`, PUT
- `PasswordUtils.hashPassword` 0x4290bc: UTF-8 → SHA-256 → digest 문자열
- `ApiService._packetId` 0x29a3f0: 이름_현재밀리초
- `ApiService.getWorkInfo` 0x2dfb04 주변: packetid / user_id
- `StepInfo.fromJson` 0x2e0790 주변: step_id, display_order, step_name, description, start_time, start_ment, end_ment, work_seconds, video_path
- `ProcessInfo.fromJson` 0x2dffb8: current_version_id가 보관된 필드가 결과의 process_version_id로 사용됨
- `WorkResultPayload.toRequestMap` 0x2a46b8: packetid, work_id, user_id, process_version_id, work_date, start_time, end_time, work_minutes, rest_minutes, result_json
- `_WorkScreenState._submitWorkResult` 0x2a376c: result_json은 Map 목록을 JSON으로 인코딩한 문자열. 저장 성공은 ret == 1.
- 결과 변환 closure 0x2d2074: stepid, 시작시간, 종료시간, 시간, 비고
- `_resolveRemarkValue` 0x2d22ac: yes/video_completed/auto_completed는 1, 그 외는 0
- `_resolveLoggedMinutes` 0x2d23f8: work_seconds를 분 단위로 올림하고 1..1440 범위로 제한
- `_currentScheduledRestWindow` 0x2d4db0: std_work_minutes + std_rest_minutes 반복 주기의 휴식 구간
- Object Pool pp+0x122a8: Duration 0x283baec00 마이크로초 = 3시간
- Object Pool pp+0x13d40: Duration 0xd693a400 마이크로초 = 1시간 로그아웃 유예
- `DeviceCheckRecord.toResultJson`: type/device_name/기기상태체크/시간/isAvailable
- `_openDeviceStatus`: kiosk_id로 항목 선택, company_device_name을 partnerId로 전달

이 자료는 정적 분석 근거입니다. 실제 서버에 로그인하거나 결과를 쓰는 검증은 하지 않았습니다. 앱 API 코드는 모의 응답 테스트로 검증합니다. 원본의 화면 전환과 모든 시간 조건의 완전한 동등성은 보장하지 않습니다.

## 1.1.0 웹 전환과 추가 안정화
웹은 Flutter JavaScript/CanvasKit 릴리스를 사용하며 WebAssembly 빌드는 아닙니다. 원본 APK 이미지와 앱 흐름을 공유합니다. YouTube는 iframe 플레이어로 교체했고 동영상은 사용자 재생으로 시작합니다. 한국어 글꼴 NanumGothic을 OFL 라이선스와 함께 포함했습니다.

진행 상태 체크포인트는 복원 작업에서 추가한 기능입니다. 사용자 ID와 작업 버전·단계 정보의 SHA-256 서명을 비교하고 유효한 상태만 적용합니다. 서버 결과 자동 재전송은 하지 않습니다. `WorkDraftService` 테스트로 재시작·사용자 격리·작업 변경·손상 데이터·만료·저장 후 제거 순서를 검증했습니다.

`scripts/test-pwa.cjs`로 브라우저 흐름을 재검증할 수 있습니다. Playwright 1.58.2와 Chromium에서 모의 API로 로그인→답변→새로고침→이어하기→결과 PUT 1회→기록 표시와 오프라인 앱 화면을 확인했습니다. 실계정 서버 쓰기는 수행하지 않았습니다. 서비스 워커는 공개 배포 파일만 캐시합니다.

## 로그인 화면 대조 (1.2.0)
원본 `_LoginScreenState.build`(0x426774), `buildLoginForm`(0x427b58), `_LoginTextField.build`(0x4a2688), `AppButton.build`(0x4a6ef0)과 객체 풀을 대조했습니다. 원본 배경 #F2F2F2, 라벨 #636363·w600, 입력 글자 #616161·힌트 #A0A0A0, 무테 입력칸 채움 #E9E9EF, loginPrimary #104B83을 반영했습니다. 짧은 변/390의 0.8~1.08 스케일, 로고 기본 180(140~210), 세로 폼 폭 84%(260~430), 가로 폼 폭 42%(280~420)와 좌우 배치, 로그인 버튼 높이 54(46~58)를 반영했습니다. 원본의 모든 오프셋·키보드 상태·픽셀 위치를 동일하게 복제한 것은 아닙니다. PWA 설치·패스키 안내는 추가 기능입니다. 작업 본문·상태·결과 화면은 계속 재작성한 복원 화면이며 원본 전체 UI와 동일하지 않습니다.
원본 `AngelApp.build`(0x424fa0 부근)의 ColorScheme seed #00C896도 반영했습니다. 원본은 Pretendard를 지정하지만 APK FontManifest에는 해당 글꼴 파일이 없으므로 Android 시스템 대체 글꼴이 사용됩니다. 웹의 한글 깨짐 방지를 위한 포함 글꼴은 유지하며 플랫폼 글꼴 차이는 남아 있습니다.

### 1.2.1: work status and completion layout

Reconstructed the common logo/message structure used by `AppMessageScreenLayout`
(AOT build at 0x4a84xx), `WorkStatusScreen` (0x4a5d08) and `ResultScreen`
(0x4a45xx). Portrait stacks logo and message; landscape places them side by side.
The original logo heights (138 portrait / 118 landscape), 390-based scale,
#111111 heading and #5A83A7 supporting text come from the AOT/heap data.
Recovered copy includes “안녕하세요!”, “편하게 쉬고 오세요!”,
“오늘도 수고하셨습니다!”, “근무기록 자세히 보기” and “퇴근하기”.
Completion includes actual recorded work start/end times and a checkout action.
User names are not invented because the recovered session does not expose one.
The scrollable layout preserves access to controls on compact screens and at large
text sizes. Scheduling, draft recovery, submission receipts and retries are retained.
The active question/video screen and history remain partial reconstructions;
this release does not claim pixel-perfect restoration of all original screens.

### 1.2.2: identify and apply PWA updates

The login screen displays v1.2.2 / build 7 to identify the loaded Flutter bundle.
A waiting service worker now presents “새 버전 적용”. Only explicit confirmation
sends ACTIVATE_UPDATE, activates the worker and reloads the requesting tab once.
Other tabs are not forcibly reloaded. Existing drafts, session vault and local
work records are preserved. The index requests a revised pwa.js URL so an older
asset allowlist cannot hide the new update UI after a network navigation.
This is an update-delivery fix; it is not a full redesign of the original APK UI.

### 1.3.0: question screen from supplied Android screenshots

The user supplied two original Android screenshots, showing speaking/listening
states of question 5/19. Rebuilt the active question layout around those images:
rounded white bordered card, overlaid original chr_rab.png, question/remaining
counter, circular settings/device/replay controls, voice-state strip, blue “예”
and orange “아니요” buttons, and the original chr_t.png on the green progress bar.
Counts derive from actual steps/questions; no sample question count is hardcoded.
Voice labels follow real TTS callbacks and speech recognition state. Replaying
stops recognition first to avoid recognizing the app's own spoken prompt.
Settings retain passkey, history, lock and logout access. Video steps retain their
existing player UI. Small screens can scroll rather than clipping controls.
This reconstructs the supplied question screen, not every original app screen.

### 1.3.1: kiosk status dialog from supplied screenshot

Restored the supplied “키오스크 현황” modal: pale rounded shell, white capacity
card, blue name, availability badge, capacity bar/percentage and outlined close
button. Values still come from the assigned kiosk in the existing authenticated
kiosk_info response; the example name and 0/1000 are not production defaults.
Invalid/missing capacities display “용량 미확인”, not a false 0% reading.
Closing the modal keeps the active question and existing device-check logging.
The video step behind the supplied modal remains outside this dialog change.

### 1.3.2: checkout login errors and durable completion

Original AuthProvider.login (0x428c5c–0x428d24) maps ret 2 to incorrect password,
3 to missing user, 4 to no login permission, 5 to inactive account, and 6 to
weekend/public holiday restriction. Restore those messages and show the response
code; do not misclassify every rejection as credentials or time restrictions.
The server still decides whether post-checkout login is allowed. No authentication
bypass or forced successful login is introduced.
Remove automatic logout from the completed screen. Explicit checkout still calls
the original logout endpoint and clears the session. Store an assignment signature
in confirmed results; on reload after successful authentication, restore same-day,
same-user, same-assignment completion instead of restarting questions. Pending
results, other users, other assignments and other days cannot establish completion.

### 1.4.0: supplied completion screen and checkout without leaving the page

Reconstructed the pale completion layout, compact logo, left-aligned greeting,
blue name and Korean AM/PM recorded times, navy history button and white checkout
button from the supplied Android screenshot. `name` comes from the original login
response field and is retained inside existing session device metadata. Missing
names are omitted. The screenshot's person and sample times are never defaults.
Explicit checkout still calls the server logout endpoint and clears credentials,
but now keeps this completion view rather than popping to login or exiting.
The button becomes “퇴근 완료”; repeated checkout is disabled. If logout cannot
be confirmed, the view says server confirmation is needed. The current user's
already loaded local history remains available read-only in this open page.
After reload the cleared session requires authentication again; no server access
or result retransmission is granted by the in-memory history snapshot.

### 1.4.1: more natural device speech

Prefer installed Korean premium/enhanced/natural voices, retain native iOS voice
identifiers, use neutral pitch and a calmer rate (web 0.95 / native 0.48). The web
bridge creates a fresh utterance per sentence and leaves a 180 ms pause between
sentences/paragraphs without splitting decimals. It initializes the voice list
early and handles delayed voice availability with Korean language fallback.
Replacing, stopping, backgrounding or answering cancels old utterances and queued
question reads; late setup cannot speak an earlier question. Autoplay rejection,
missing speech support and platform errors leave manual answer controls usable.
A watchdog releases a browser that never reports speech completion. No application
cloud speech endpoint, credential or paid API is introduced. Voice quality still
depends on installed OS/browser voices; no real-device listening comparison is
claimed by the synthetic engine tests.

### v1.5.0: video, preferences and work history

Video steps now use the same rabbit question card, counter and turtle progress as text questions (original video builder `0x4304b8` and the supplied kiosk-over-video screenshot). A failed video remains on its step with explicit retry; it is not recorded as completed. Opening settings/device status or leaving the foreground pauses playback; returning requires manual playback. A generated four-second clip exercises real browser media playback, failure/retry and modal pause against mocked APIs.

The device-local automatic question reading preference persists independently of authentication; manual replay remains available when disabled. Original speech idle/unavailable messages are grounded in AOT `0x42dc34`/`0x42dc58`. No paid speech provider or server-side speech capability is implied.

History shows actual locally stored start/end times, work/rest minutes and answers. Today/all filters retain older unconfirmed records in the default view. Detail labels follow original strings `오늘의 근무 기록` (`0x4a3184`), `근무 시작` (`0x4a3700`), `근무 종료` (`0x4a3804`), `일일 근무 성과` (`0x4a1a0c`), `확인했어요` (`0x4a1204`). Unknown data remains unknown, and elapsed/assigned-time bars do not claim a server performance score. Checkout retains read-only history without authorizing network retries after logout.

This is evidence-based restoration of these flows, not verification of complete original-app parity. Real server access, real iOS speech quality and every original video/source are unavailable for end-to-end verification.
