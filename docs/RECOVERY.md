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
