#!/usr/bin/env bash
# Build a signed debug APK and install on a connected device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/NebulaDawn-debug.apk"
UNSIGNED="$ROOT/build/NebulaDawn-unsigned.apk"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
ANDROID_SDK_ROOT="$ANDROID_HOME"
BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
KEYSTORE="${KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"
JAVA_BIN="$(command -v java)"
JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")}"

export ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$ROOT/build"
rm -f "$UNSIGNED" "$OUT"

godot --headless --path "$ROOT" --export-debug "Android" "$UNSIGNED"

if [[ ! -f "$UNSIGNED" ]]; then
  echo "Export failed: no APK at $UNSIGNED" >&2
  exit 1
fi

# NixOS: apksigner shebang points at /bin/bash which may not exist — invoke via bash.
bash "${BUILD_TOOLS}apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$OUT" \
  "$UNSIGNED"
rm -f "$UNSIGNED" "$OUT.idsig"

bash "${BUILD_TOOLS}apksigner" verify --print-certs "$OUT"
ls -lah "$OUT"

adb start-server >/dev/null 2>&1 || true
adb install -r "$OUT"
