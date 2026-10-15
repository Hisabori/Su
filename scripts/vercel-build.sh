#!/usr/bin/env bash
set -euo pipefail
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
if ! command -v flutter >/dev/null 2>&1; then
  # A restored .vercel/cache can contain a partial checkout or stale Git metadata.
  # A fresh directory also avoids reusing SDK files owned by a different runner.
  sdk_parent="$(mktemp -d "${TMPDIR:-/tmp}/suho-flutter.XXXXXX")"
  sdk_path="$sdk_parent/flutter"
  if ! git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$sdk_path"; then
    # Use the official, checksum-verified SDK when Git fetching is unavailable.
    rm -rf "$sdk_path"
    curl --fail --location --retry 3 --max-time 60 \
      https://storage.googleapis.com/flutter_infra_release/flutter/releases/releases_linux.json \
      -o "$sdk_parent/releases.json"
    python3 - "$sdk_parent/releases.json" > "$sdk_parent/release.txt" <<'PY'
import json, re, sys
with open(sys.argv[1]) as source:
    manifest = json.load(source)
release = next(item for item in manifest['releases'] if item['version'] == '3.47.7' and item['channel'] == 'stable')
assert release['archive'] == 'stable/linux/flutter_linux_3.47.7-stable.tar.xz'
assert re.fullmatch(r'[0-9a-f]{64}', release['sha256'])
print(release['archive'])
print(release['sha256'])
PY
    mapfile -t sdk_release < "$sdk_parent/release.txt"
    sdk_archive="$sdk_parent/flutter.tar.xz"
    curl --fail --location --retry 3 --max-time 600 \
      "https://storage.googleapis.com/flutter_infra_release/flutter/${sdk_release[0]}" -o "$sdk_archive"
    printf '%s  %s\n' "${sdk_release[1]}" "$sdk_archive" | sha256sum --check -
    tar --no-same-owner -xf "$sdk_archive" -C "$sdk_parent"
  fi
  export PATH="$sdk_path/bin:$PATH"
fi
bash scripts/build-web.sh
