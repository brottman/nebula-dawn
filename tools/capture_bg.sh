#!/usr/bin/env bash
# Offscreen-render the parallax backdrop to a PNG for visual review.
# Requires godot + weston + mesa on PATH (nix shell nixpkgs#weston nixpkgs#godot nixpkgs#mesa --command ...).
# Usage: ./tools/capture_bg.sh <style> <out.png> [warmup_s]
set -euo pipefail
STYLE="${1:-city}"
OUT="${2:-docs/previews/bg.png}"
WARM="${3:-5}"

MESA_JSON="$(find /nix/store -path '*mesa-*/share/glvnd/egl_vendor.d/50_mesa.json' 2>/dev/null | head -1)"
if [[ -n "$MESA_JSON" ]]; then
  export __EGL_VENDOR_LIBRARY_FILENAMES="$MESA_JSON"
fi
export XDG_RUNTIME_DIR=/tmp/opencode/xdg
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

SOCKET="wayland-bg-$$"
weston --backend=headless-backend.so --socket="$SOCKET" --width=480 --height=720 \
  >/tmp/opencode/weston.log 2>&1 &
WPID=$!
trap 'kill "$WPID" 2>/dev/null || true' EXIT
sleep 2

WAYLAND_DISPLAY="$SOCKET" LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver wayland \
  --rendering-driver opengl3 --script res://tools/capture_background.gd -- "$STYLE" "$OUT" "$WARM"
