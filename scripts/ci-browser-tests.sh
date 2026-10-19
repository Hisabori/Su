#!/usr/bin/env bash
set -euo pipefail
if [ -n "${PWA_SCREENSHOT_DIR:-}" ]; then mkdir -p "$PWA_SCREENSHOT_DIR"; fi
npm ci --ignore-scripts --prefix browser-tests --no-audit --no-fund
export NODE_PATH="$PWD/browser-tests/node_modules"
export CHROMIUM_PATH="${CHROMIUM_PATH:-/usr/bin/google-chrome}"
node scripts/test-speech.cjs
node scripts/test-pwa-update.cjs
node scripts/test-passkey-vault.cjs
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web > /tmp/suho-pwa-test-server.log 2>&1 &
pwa_server_pid=$!
trap 'kill "$pwa_server_pid" 2>/dev/null || true' EXIT
for attempt in {1..30}; do
  if curl --fail --silent http://127.0.0.1:8765/ > /dev/null; then break; fi
  sleep 0.2
done
browser_status=0
node scripts/test-passkey-flow.cjs || browser_status=1
node scripts/test-pwa.cjs || browser_status=1
node scripts/test-video-flow.cjs || browser_status=1
node scripts/test-community-flow.cjs || browser_status=1
node scripts/test-device-flow.cjs || browser_status=1
exit "$browser_status"
