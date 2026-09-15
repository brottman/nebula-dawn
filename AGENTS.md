# Nebula Dawn — Agent Workflow

This is the per-project agent guide for `nebula-dawn` (Godot 4 game).

## Versioning — MUST BUMP ON EVERY CODE CHANGE
**Single source of truth:** `VERSION` file at repo root and `scripts/ui/main_menu.gd:APP_VERSION` + `scenes/ui/main_menu.tscn:Version` label.

- Current version: `v0.14.20` (see `VERSION`)
- **Every agent code change** (gameplay, art, balance, UI) **MUST**:
  1. Bump `VERSION` (patch `v0.14.10` → `v0.14.11`, minor for features, major for breaking)
  2. Update `scripts/ui/main_menu.gd:APP_VERSION` to match `VERSION`
  3. Update `scenes/ui/main_menu.tscn:Version` `text` to match
  4. Visible at bottom-left of Main Menu — user uses this to verify deploy wasn't overwritten/cached

Do not skip — user explicitly requested this after repeated "code got overwritten" suspicion.

## Build / Run
```bash
godot --headless --import              # reimport SVGs after art changes
godot --headless --path . --script res://tools/validate_project.gd
godot --headless --path . --script res://tools/test_player.gd
```

APK: `bash scripts/build_apk.sh` (signed release APK). It builds against a
**pinned Godot 4.7.2** (`GODOT_FLAKE` in the script) because `project.godot`
targets `4.7` and nixpkgs' default `godot` is older (4.6.x). Set `GODOT=` to
override.

Visual previews (offscreen render) live in `docs/previews/` (tracked, visible
in the Godot File System dock). The export preset excludes `docs/previews/*`
so they never ship in the APK:
`nix shell nixpkgs#weston nixpkgs#godot nixpkgs#mesa --command ./tools/capture_bg.sh city docs/previews/bg.png 5`
and `tools/capture_game.gd` for a live gameplay frame.

## Project Notes
- Asteroid art lives in `assets/sprites/enemy_asteroid.svg` (keep reimport after edit)
- Hangar/ship loadout via `GameState` autoload
- Do not SSH to superheavy/backup to edit — edit local `~/dotfiles` and `~/projects/nebula-dawn` only
