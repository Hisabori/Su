# Antigravity · IntelliJ IDEA 개발 환경

저장소를 클론한 뒤 `pubspec.yaml`이 있는 루트 폴더를 엽니다. 생성된 `build/web` 폴더가 아니라 `lib/`의 Flutter 소스를 편집합니다.

## 준비

- Flutter stable **3.47.7**: CI와 동일한 버전입니다. Dart는 Flutter에 포함된 버전을 사용합니다.
- Chrome, Node.js **22 이상**, Python **3**: 웹 실행·서버 테스트·PWA 빌드에 사용합니다.
- iOS 실행은 macOS와 Xcode가 필요합니다. Windows/Linux에서는 웹을 개발하고 GitHub Actions에서 IPA를 빌드할 수 있습니다.

터미널에서 다음을 실행합니다.

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
npm install --ignore-scripts --no-audit --no-fund
```

SDK는 개인 PC에 설치하고 PATH에 추가합니다. 로컬 SDK 절대 경로나 비밀번호·토큰·Vercel 환경 파일을 저장소에 커밋하지 않습니다.

## Antigravity

1. 프로젝트 루트 폴더를 엽니다.
2. 해당 Antigravity 버전에서 지원하는 Dart/Flutter 확장을 설치합니다. `.vscode/extensions.json`에 추천 확장 ID가 있습니다. 확장 설치 가능 여부는 Antigravity 버전에 따라 다릅니다.
3. 실행 및 디버그에서 **수호천사 · Chrome**을 선택합니다. 허용된 개발 주소인 `http://127.0.0.1:8765`에서 열립니다.
4. Tasks 메뉴에서 **Flutter: 코드 검사**, **Flutter: 전체 테스트**, **Node: 서버 테스트**를 실행합니다. 기본 빌드 작업 **PWA: 배포용 빌드**는 Flutter 컴파일 후 오프라인 캐시 준비까지 수행합니다.

확장이나 실행 프로필이 인식되지 않으면 아래 공통 터미널 명령으로 동일한 작업을 수행할 수 있습니다.

## IntelliJ IDEA

1. Plugins에서 Flutter 플러그인과 Dart 플러그인을 설치하고 IDE를 재시작합니다. 플러그인이 현재 IDEA 버전을 지원하는지 확인합니다.
2. 프로젝트 루트를 Open으로 엽니다. Flutter SDK 경로를 IDE 설정의 Languages & Frameworks → Flutter에서 지정합니다.
3. 공유 실행 설정 **수호천사 · Chrome**을 선택합니다. `.run/Suho_Chrome.run.xml`을 인식하지 못하면 Run → Edit Configurations → Flutter에서 `lib/main.dart`, 기기 Chrome, 추가 인수 `--web-port=8765 --web-hostname=127.0.0.1`를 지정합니다.
4. `test/`의 테스트를 IDE에서 실행하거나 아래 명령을 사용합니다. 개인 작업 상태가 들어 있는 `.idea/`는 기존대로 Git에서 제외합니다.

## 공통 명령

```sh
flutter run -d chrome --web-port=8765 --web-hostname=127.0.0.1
flutter analyze
flutter test
node --test test-js/community.test.cjs test-js/diagnostics.test.cjs
```

macOS/Linux/Git Bash에서는 기존 배포 빌드 스크립트를 사용할 수 있습니다.

```sh
bash scripts/build-web.sh
```

PowerShell에서는 다음과 같이 빌드합니다.

```powershell
flutter pub get --enforce-lockfile
flutter build web --release --no-web-resources-cdn --base-href=/
python scripts/prepare-pwa.py
```

빌드 결과는 `build/web`입니다. 배포 시에는 기존 Vercel 프로젝트의 연결 설정을 사용합니다. IDE 설정 자체는 배포나 서버 데이터 초기화를 실행하지 않습니다.

## 서버 연결과 진단 로그

앱의 기본 로그인·근무 API는 기존 실제 서버입니다. 로그인·근무 결과 저장은 실제 서버 동작을 수행하므로 테스트 계정을 사용하세요. 커뮤니티와 진단 API는 배포된 Vercel 서버를 사용하며, Vercel 서버 환경 변수는 IDE 설정에 포함하지 않았습니다. 오프라인에서 서버 기능까지 재현되는 것은 아닙니다.

브라우저 자동 검사는 `scripts/ci-browser-tests.sh`의 모의 API를 사용합니다. 브라우저 검사의 Chromium·Playwright 준비 과정은 GitHub의 Web PWA Build 워크플로를 참고합니다.

진단 이벤트는 콘솔에 `suho_diagnostic`으로 표시됩니다. 원격 진단 전송은 정식 `https://suho-angel.vercel.app`에서만 수행하며 로컬 개발에서는 보내지 않습니다. Vercel Runtime Logs에서 이벤트 이름 또는 오류 화면의 확인 번호로 찾습니다. 진단에는 비밀번호·토큰·사용자명·기록 본문을 포함하지 않으며 Vercel 로그 보존 기간은 프로젝트 요금제 설정을 따릅니다.
