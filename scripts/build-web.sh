#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Git Bash must pass URL paths to flutter.bat without MSYS path conversion.
export MSYS_NO_PATHCONV=1
flutter pub get --enforce-lockfile
flutter build web --release --no-web-resources-cdn --base-href "${WEB_BASE_HREF:-/}" --dart-define="API_BASE_URL=${API_BASE_URL:-https://api-suho1004.innaim.com}"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
  python3 scripts/prepare-pwa.py
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
  python scripts/prepare-pwa.py
elif command -v py >/dev/null 2>&1; then
  py -3 scripts/prepare-pwa.py
else
  echo 'Python 3 is required (python3, python or py -3).' >&2
  exit 1
fi
