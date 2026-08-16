#!/usr/bin/env bash
# Build a signed release APK (export + sign only — does not install).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/NebulaDawn-release.apk"
UNSIGNED="$ROOT/build/NebulaDawn-unsigned.apk"
KEYSTORE="${KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"
KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-androiddebugkey}"
KEYSTORE_PASS="${KEYSTORE_PASS:-android}"
KEYSTORE_KEY_PASS="${KEYSTORE_KEY_PASS:-$KEYSTORE_PASS}"
PRESETS="$ROOT/export_presets.cfg"
PACKAGE_UNIQUE_NAME="com.nebuladawn.game"
PACKAGE_NAME="Nebula Dawn"

# Prefer Godot from PATH (e.g. nix shell nixpkgs#godot).
if [[ -z "${GODOT:-}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    echo "godot not found on PATH. Try: nix shell nixpkgs#godot --command $0" >&2
    exit 1
  fi
fi

JAVA_BIN="$(command -v java)"
JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")}"

# Editor settings use $HOME/Android; also accept common SDK layouts.
if [[ -z "${ANDROID_HOME:-}" ]]; then
  for candidate in "$HOME/Android" "$HOME/Android/Sdk" "$HOME/.local/android-sdk"; do
    if [[ -d "$candidate/build-tools" ]]; then
      ANDROID_HOME="$candidate"
      break
    fi
  done
fi
ANDROID_HOME="${ANDROID_HOME:?Android SDK not found. Set ANDROID_HOME.}"
ANDROID_SDK_ROOT="$ANDROID_HOME"
BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
BUILD_TOOLS="${BUILD_TOOLS:?No build-tools under $ANDROID_HOME}"

export ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

# export_presets.cfg is gitignored (may hold keystore paths); create a preset if missing.
if [[ ! -f "$PRESETS" ]]; then
  cat >"$PRESETS" <<EOF
[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
version/code=1
version/name="1.0"
package/unique_name="${PACKAGE_UNIQUE_NAME}"
package/name="${PACKAGE_NAME}"
package/signed=true
package/app_category=2
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
architectures/arm64-v8a=true
architectures/armeabi-v7a=false
architectures/x86=false
architectures/x86_64=false
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
command_line/extra_args=""
EOF
  echo "Created $PRESETS"
fi

mkdir -p "$ROOT/build"
rm -f "$UNSIGNED" "$OUT"

# The preset sets package/signed=true, so Godot tries to sign during export and
# fails if no keystore is configured in editor settings. That leaves the
# unsigned APK behind (which is what we want) but exits nonzero — do not let
# `set -e` abort before the apksigner step below.
set +e
"$GODOT" --headless --path "$ROOT" --export-release "Android" "$UNSIGNED"
export_status=$?
set -e

if [[ ! -f "$UNSIGNED" ]]; then
  echo "Export failed: no APK at $UNSIGNED (godot exit $export_status)" >&2
  exit 1
fi

# NixOS: apksigner shebang may point at a missing /bin/bash — invoke via bash.
bash "${BUILD_TOOLS}apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias "$KEYSTORE_ALIAS" \
  --ks-pass "pass:$KEYSTORE_PASS" \
  --key-pass "pass:$KEYSTORE_KEY_PASS" \
  --out "$OUT" \
  "$UNSIGNED"
rm -f "$UNSIGNED" "$OUT.idsig"

bash "${BUILD_TOOLS}apksigner" verify --print-certs "$OUT"
ls -lah "$OUT"
echo "APK ready: $OUT"
