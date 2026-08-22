# Nebula Dawn — Agent Workflow

This is the per-project agent guide for `nebula-dawn` (Godot 4 game).

## Versioning — MUST BUMP ON EVERY CODE CHANGE
**Single source of truth:** `VERSION` file at repo root and `scripts/ui/main_menu.gd:APP_VERSION` + `scenes/ui/main_menu.tscn:Version` label.

- Current version: `v0.14.10` (see `VERSION`)
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

## Project Notes
- Asteroid art lives in `assets/sprites/enemy_asteroid.svg` (keep reimport after edit)
- Hangar/ship loadout via `GameState` autoload
- Do not SSH to superheavy/backup to edit — edit local `~/dotfiles` and `~/projects/nebula-dawn` only
