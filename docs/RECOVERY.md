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
