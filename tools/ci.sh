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

echo "==> import / class cache"
"$GODOT" --headless --path . --editor --quit-after 1

echo "==> validate_project"
"$GODOT" --headless --path . --script res://tools/validate_project.gd

echo "==> test_player"
"$GODOT" --headless --path . --script res://tools/test_player.gd

echo "==> smoke_test"
"$GODOT" --headless --path . --script res://tools/smoke_test.gd

echo "==> smoke_boss_rush"
"$GODOT" --headless --path . --script res://tools/smoke_boss_rush.gd

echo "CI OK"