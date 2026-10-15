# 수호천사 iOS 앱 재구성 · 사이드로딩

APK에서 추출한 이미지와 코드 이름을 근거로 새로 작성한 Flutter 앱 소스입니다. 원본 Dart 소스를 완전히 복구한 것이 아닙니다.

현재 구현: 로그인 화면, 로그인/작업조회 API 어댑터, 토큰 저장, 작업 정보 화면과 읽어주기. 음성 인식 서비스 클래스는 있지만 화면에는 연결하지 않았습니다.
미구현: 원래 작업/휴식 시간 관리, 영상·질문·답변 흐름, 결과 제출 및 결과 기록, 키오스크 제한, 토큰 갱신, 서버 로그아웃. 원래 UI와 동일함을 보장하지 않습니다.

## 기존 서버 연결
원본 서버의 요청·응답 형식을 아직 제공받지 못했습니다. 따라서 서버 통신은 기본적으로 비활성화되어 있습니다.
lib/services/api_service.dart의 로그인 메서드, 비밀번호 인코딩, 토큰 응답 키, 작업 정보 스키마를 실제 서버 코드와 대조해 수정해야 합니다. 문자열에서 키 이름이 발견되어도 실제 API 구조가 확인된 것은 아닙니다.
PASSWORD_ENCODING=plain 또는 sha256은 선택 가능한 구현일 뿐, 원래 앱의 비밀번호 처리 방식으로 검증된 값이 아닙니다. 서버 방식이 다르면 password_utils.dart를 수정하세요.

## Mac에서 IPA 생성
1. Flutter 3.47.7 stable(이번 프로젝트 생성에 사용한 버전), Xcode와 필요한 iOS dependency 도구를 설치하고 Xcode 초기 설정을 완료합니다.
2. 이 폴더에서 flutter pub get 을 실행합니다.
3. iOS 프로젝트에 필요한 의존성을 설치합니다. CocoaPods 사용 프로젝트라면 ios 폴더에서 pod install 을 실행합니다.
4. ./scripts/build-sideload.sh 를 실행하면 build/ios/ipa/suhoangel-unsigned.ipa가 생성됩니다.
5. AltStore 또는 Sideloadly에서 IPA를 본인 Apple 계정으로 서명해 iPhone에 설치합니다. 일반 무료 계정은 통상 7일마다 갱신이 필요하며, 도구/계정에 따라 설치 제한이 적용됩니다. 필요하면 iPhone의 개발자 모드를 켜고 해당 개발자를 신뢰합니다.

서버 계약을 확인한 후 빌드 명령 예시:
./scripts/build-sideload.sh --dart-define=API_CONTRACT_VERIFIED=true --dart-define=PASSWORD_ENCODING=sha256
위 sha256 값은 예시입니다. 실제 서버 방식으로 바꾸세요. 비밀번호나 서버 비밀키를 dart-define으로 넣지 마세요.

서명하지 않은 IPA는 직접 설치할 수 없고 설치 도구의 재서명이 필요합니다. Apple 로그인은 설치 도구에서 직접 수행하세요.

## 검증 상태
이 작업 환경은 Linux이며 Xcode가 없어 iOS 빌드, 서명 및 실제 iPhone 테스트를 수행할 수 없습니다. APK도 실행하지 않았으며 기존 서버에 요청하지 않았습니다.

검사 결과: flutter analyze 통과, 자동 테스트 4개 통과. iOS 배포 대상은 생성된 프로젝트 기준 iOS 15.0 이상입니다. 기본 Flutter 앱 아이콘을 사용하며 앱 아이콘 교체는 남아 있습니다.

## GitHub 빌드
.github/workflows/ios-sideload.yml은 main에 push하거나 Actions에서 직접 실행할 수 있습니다. macOS runner에서 검사 후 미서명 IPA를 빌드해 suhoangel-unsigned-ipa artifact로 14일간 보관합니다. Apple 계정/인증서는 CI에 넣지 않습니다. 다운로드한 ZIP을 풀고 IPA를 AltStore 또는 Sideloadly에 전달하세요. 서버 연결은 기본적으로 비활성화된 상태로 빌드됩니다.
