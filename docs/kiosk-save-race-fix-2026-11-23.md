# 작업 중 키오스크 점검 저장 누락 수정

대상은 근로자 PWA `suho-angel.vercel.app`의 로컬 소스다.
관리자 데이터 내보내기·사이트 복사는 사용자 요청으로 취소했다.
운영 근무 결과를 새로 만들거나 기존 결과를 수정하지 않는다.

## 수정 전 재현

기존 1.24.1 웹 산출물에 모의 API를 연결하고 다음 순서로 검사했다.

1. 근무를 시작하고 설정의 ‘기기 기록 · 그래프’를 누른다.
2. 브라우저의 실제 보안 저장소 복호화 읽기를 일시 지연한다.
3. 근무 자동 종료 시각으로 이동한다.
4. 저장소 읽기를 재개하고 전송된 모의 work_result JSON을 검사한다.

결과는 work_result 1회 전송, **device_check 0건**이었다.
기대값 1건과 달라 새 회귀 검사가 실패했다.
증거: `build/kiosk-prepare-race-before.log`.
이는 코드 경합의 재현이며, 과거 운영 결과 1798의 유일한 원인을 확정한 것은 아니다.

## 원인

기존 showDeviceHistory는 사용자·배정 정보 읽기와 음성 중지를 마친 뒤 수동 조회를 등록했다.
showDevice도 음성 중지 후에야 등록했다.
이 준비 과정에서 자동 종료가 먼저 실행되면 종료 함수가 기다릴 조회 목록에 항목이 없었다.
뒤늦게 조회를 시작할 때는 이미 저장 대기 상태여서 근무 기록 대상에서 제외됐다.

## 변경

- 수거기 버튼을 누른 시점의 근무 자격과 사용자를 먼저 캡처한다.
- 준비 작업을 기다리기 전에 조회 Future를 대기 목록에 등록한다.
- 음성 중지·저장소 읽기·API 조회·journal 저장까지 종료 함수가 기다린다.
- 일반 답변 처리의 임시 saving 상태만으로 유효한 근무 중 점검을 버리지 않는다.
- 완료·저장 대기·실제 제출 중·퇴근·다른 사용자 조건은 계속 차단한다.
- 시작 전 조회 및 10분 그래프 이력을 임의로 근무 결과에 합치지 않는다.
- 결과는 기존 스키마로 한 번만 제출한다. 조회 시점의 work_result 전송을 추가하지 않는다.

수정본 식별자는 **1.24.2 / 빌드 38**이다.
초기 검증은 로컬만 수행했다. 이후 사용자가 라이브 적용을 명시적으로 요청해
점검 저장 수정과 관련 호환 코드만 main에 반영하고 production 배포를 확인한다.

## 검증 기록

수정 전 실패와 동일한 조건에서 수정 후 work_result 1회·device_check 1건(1.2%)을 확인했다.

- Flutter 3.47.9 / Dart 3.13.7: analyze 문제 없음 (`build/kiosk-save-analyze.log`).
- 전체 Flutter 테스트 120개 통과 (`build/kiosk-save-tests.log`). 생성된 unit_test_assets 디렉터리의 읽기 전용 속성 때문에 첫 시도는 실행되지 않았고, 해당 생성 디렉터리 속성만 해제한 뒤 재실행했다.
- 수거기 Node 테스트 11개 통과 (`build/kiosk-save-node-tests.log`).
- 잠금 파일 강제 검사 후 JavaScript 웹 release 컴파일 성공. 기존 Wasm dry-run 및 Cupertino 폰트 경고는 남아 있다 (`build/kiosk-save-build.log`).
- 실행 환경 PATH에 Windows Python 별칭 디렉터리가 없어 후처리가 처음 중단됐다. local-tools.ps1에 설치된 사용자 WindowsApps Python 경로 탐색을 추가하고 후처리를 재실행해 성공했다 (`build/kiosk-save-prepare.log`, cache c92e76d852a09a13).
- Chrome 모의 API 회귀 6개 시나리오 그룹 통과 (`build/kiosk-save-browser.log`): 준비 지연/자동 종료, 수동 조회·재시도·새로고침 초안 복구·단일 전송·완료 후 읽기 전용, HTTP 응답 지연/자동 종료, 422 partnerIds 호환, kioskID·공백·숫자 문자열 호환, 시작 전 조회 제외.

모든 결과 전송 검증은 모의 API다. 이 수정본으로 운영 관리자 DB 저장·표시를 검증하지 않았다.

- 추가 근무 흐름 회귀 8개 항목 통과: 서버 시각 시작, 그래프 복귀, 초안/음성/스타일 복원, 단일 전송, 완료 복원, 퇴근 및 서버 거절 처리, 오프라인 셸 (`build/kiosk-save-work-regression.log`).
- 외부 요청 차단 로컬 PWA smoke 통과: errors/failed 비어 있음, offlineShell true (`build/kiosk-save-smoke.log`).
- ZIP CRC 검사 통과 (`build/kiosk-save-package.log`).
  - `build/artifacts/suho-angel-pwa-1.24.2-local.zip`: SHA256 `fd3b8a95f2951a30a4caca85c34d602e0b76ab96e6b167487f5c2ad4db113f9c`
  - `build/artifacts/suho-angel-local-runner-1.24.2.zip`: SHA256 `e22bdf7e5b9da8098ea3b9207ca2d6a84665300476f44f0fe7c44038271af2de`

로컬 실행: `node scripts/serve-web.cjs 8080`, 주소 `http://localhost:8080`, 종료 Ctrl+C.
실행용 ZIP은 전체 압축 해제 후 Start-Local.cmd 실행(Node.js 필요).
기존 브라우저 초안은 origin별 저장이므로 기존 origin을 바꿔도 자동 이전되지 않는다.
