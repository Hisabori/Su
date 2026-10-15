#!/usr/bin/env bash
set -euo pipefail
flutter pub get --enforce-lockfile
flutter build web --release --no-web-resources-cdn --base-href "${WEB_BASE_HREF:-/}" --dart-define="API_BASE_URL=${API_BASE_URL:-https://api-suho1004.innaim.com}"
python3 scripts/prepare-pwa.py
