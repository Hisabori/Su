#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'IPA 빌드는 macOS와 Xcode가 필요합니다.' >&2
  exit 1
fi
cd "$(dirname "$0")/.."
command -v flutter >/dev/null
xcodebuild -version
flutter pub get
flutter build ios --release --no-codesign "$@"
app_path='build/ios/iphoneos/Runner.app'
[[ -d "$app_path" ]]
bundle_dir="$(mktemp -d)"
trap 'rm -rf "$bundle_dir"' EXIT
mkdir "$bundle_dir/Payload"
cp -R "$app_path" "$bundle_dir/Payload/Runner.app"
mkdir -p build/ios/ipa
output_path="$PWD/build/ios/ipa/suhoangel-unsigned.ipa"
(cd "$bundle_dir" && /usr/bin/zip -qry "$output_path" Payload)
echo "Unsigned IPA: $output_path"
echo 'AltStore 또는 Sideloadly에서 본인 Apple 계정으로 다시 서명한 후 설치하세요.'
