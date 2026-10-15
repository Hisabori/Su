#!/usr/bin/env bash
set -euo pipefail
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
if ! command -v flutter >/dev/null 2>&1; then
  sdk_path="$PWD/.vercel/cache/flutter-3.47.7"
  if [[ ! -x "$sdk_path/bin/flutter" ]]; then
    git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$sdk_path"
  fi
  export PATH="$sdk_path/bin:$PATH"
fi
bash scripts/build-web.sh
