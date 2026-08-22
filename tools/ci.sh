#!/usr/bin/env bash
# Headless validation + smokes. Prefer: nix shell nixpkgs#godot --command ./tools/ci.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GODOT:-}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    echo "godot not found on PATH. Try: nix shell nixpkgs#godot --command $0" >&2
    exit 1
  fi
fi

# Godot --script often exits 0 on compile errors; treat SCRIPT ERROR as failure.
run_godot() {
  local label="$1"
  shift
  echo "==> $label"
  local log
  log="$(mktemp)"
  set +e
  "$GODOT" "$@" >"$log" 2>&1
  local status=$?
  set -e
  cat "$log"
  if [[ "$status" -ne 0 ]]; then
    rm -f "$log"
    exit "$status"
  fi
  if grep -q "SCRIPT ERROR" "$log"; then
    echo "SCRIPT ERROR during $label" >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
}

echo "==> import / class cache"
"$GODOT" --headless --path . --editor --quit-after 1

run_godot validate_project --headless --path . --script res://tools/validate_project.gd
run_godot test_hangar --headless --path . --script res://tools/test_hangar.gd
run_godot test_player --headless --path . --script res://tools/test_player.gd
run_godot smoke_test --headless --path . --script res://tools/smoke_test.gd

echo "CI OK"
