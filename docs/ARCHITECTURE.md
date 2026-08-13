# Architecture

Technical overview of Nebula Dawn’s runtime systems.

## High-level flow

```
MainMenu
  ├─ Campaign → GameWorld (campaign mission)
  ├─ Settings (standalone scene)
  └─ Boss Rush → GameWorld (raid arenas)

GameWorld
  ├─ ParallaxBg          # 4 scroll layers
  ├─ Player              # facade over WeaponSystem / LifeSystem
  ├─ Entities            # enemies, hazards, stage props
  ├─ Projectiles         # pooled bullets
  ├─ WaveSpawner         # campaign waves
  ├─ MissionRunner       # win / lose
  ├─ FormationTracker    # Stage 1 chain reactions
  ├─ StageDirector       # loads one StageGimmick by gimmick_id
  ├─ HUD                 # lives / score / weapon / chips via EventBus
  ├─ PauseMenu           # Settings overlay (run stays loaded)
  └─ on win → victory exit tween → MissionResults
```

## Campaign progression

1. `GameState.start_campaign_mission(index)` sets mode + mission index and clears session score.
2. `GameWorld` loads `MissionData` from `GameState.MISSION_PATHS`.
3. `StageDirector.begin(data)` instantiates the gimmick module (`gimmick_id`).
4. `MissionRunner.begin_campaign(data)` starts `WaveSpawner`.
5. Waves advance via **hybrid clear** (all *this wave’s* enemies dead **or** `max_clear_time`).
6. After waves: optional Act 5 boss (`MissionData.boss`).
7. `MissionRunner` records result → `GameWorld` plays victory outro (if won) → results scene.

Unlocks: clearing stage *N* unlocks *N+1* (`highest_unlocked_mission`). Saved in `user://nebula_dawn.cfg`.

## Wave spawning

`WaveSpawner` owns:

- Campaign scripted waves from `MissionData.waves`

Per-wave bookkeeping uses `_wave_enemies_alive` so leftovers from a **timed-out** wave do not block the next wave’s clear condition.

`SpawnEntry.formation_id`: when non-empty, all units in that entry register with `FormationTracker`. Killing the last member triggers a chain reaction (bullet clear + bonus pickup).

## Combat

### Collision layers (`project.godot`)

| Bit | Name | Typical use |
|-----|------|-------------|
| 1 | player | Player ship |
| 2 | player_projectile | Player bullets |
| 4 | enemy | Enemies / bosses / terminals |
| 8 | enemy_projectile | Enemy bullets |
| 16 | pickup | Power-ups |
| 32 | hazard | Asteroids, barriers |
| 64 | barrier_wall | Solid barrier bodies (block the player ship) |

Player bullets hit enemies + hazards. Enemy bullets hit player + hazards (rocks absorb fire).

### Projectiles

`ProjectilePool` recycles `Area2D` bullets. Player shots support opts: `pierce`, `homing`, `wave_amp` / `wave_freq`, `lifetime`, `scale`, `color`.

`clear_enemy_in_radius(center, r)` cancels enemy bullets (formations, terminals, victory freeze).

### Enemies

`enemy_base.gd` + shared scene. Behavior from `EnemyStats`:

- Patterns: `DIVE`, `STRAFE`, `DRIFT`, `BOSS`
- Boss fire is dispatched by `BossPatterns` using `EnemyStats.boss_archetype` (never `display_name`)
- Mid-boss: `is_boss` + `is_mid_boss` — uses boss HUD, does **not** end the mission
- Asteroids: split into smaller tiers on death; `absorb_bullet` for blocked enemy shots
- Sprites from `assets/sprites/` with light color modulate for variants
- `_sprite_path_for` prefers `BOSS_SPRITE_PATHS` / `MID_SPRITE_PATHS` by archetype; Sector 1 stage bosses fall back to generic `enemy_boss.svg`

Stage bosses: `orbital`, `megalith`, `leviathan`, `fabrication`, `omega`, `kaleidoscope`, `tempest`, `choir`, `junkyard`, `dawn`.

Mid-bosses: `transport`, `drill`, `stalker`, `overseer`, `ace`, `prism`, `coil`, `echo`, `tyrant`, `herald`.

## Stage gimmicks (`StageDirector`)

`StageDirector` is a thin loader. `GIMMICKS` maps each `gimmick_id` to a `StageGimmick` script under `scripts/stage/gimmicks/`. The active module gets `bind` / `begin` / `tick` / boss hooks. Toast-only modules (`formations`, `asteroids`) still instantiate so the HUD toast fires; the real work lives elsewhere.

| `gimmick_id` | Module | Runtime behavior |
|--------------|--------|------------------|
| `formations` | `formations.gd` | Toast only; chain wipes live on `FormationTracker` |
| `asteroids` | `asteroids.gd` | Toast only; split/block is in enemy/projectile code |
| `nebula` | `nebula.gd` | Fog overlay + drifting plasma (`enter_plasma` / `exit_plasma`) |
| `hive` | `hive.gd` | Barrier pairs + shootable terminals on a pulse timer |
| `gravity` | `gravity.gd` | Spawns singularities; pull + graze Overdrive live on `singularity.gd` (`setup(player, pool)`) |
| `mirrors` | `mirrors.gd` | Mirror plates bounce enemy bullets sideways |
| `ion` | `ion.gd` | Vertical lightning columns pulse across lanes |
| `phantoms` | `phantoms.gd` | Fog + delayed echo volleys at the ship’s last position |
| `scrap` | `scrap.gd` | Horizontal conveyors set `player.scrap_push` |
| `flare` | `flare.gd` | Solar flare wash on the lower field; residual gravity wells |

## Player

`player_ship.gd` is the public facade (`hp`, `lives`, `apply_pickup`, `try_use_bomb`, `_emit_weapon_changed`, `_try_death_bomb`, `_death_bomb_time`, …). HUD / GameWorld / pickups still call the ship; `WeaponSystem` and `LifeSystem` are child nodes in `player.tscn`.

- `WeaponSystem` — color weapons, shared power tier, drones, speed
- `LifeSystem` — hull, lives, shields, bombs, death/respawn, volcano drop, Overdrive, plasma
- Touch-follow or keyboard 8-way
- Auto-fire: stock Blaster + color weapons (Red Spread / Blue Laser / Green Homing)
- Universal power tier (Lv1–3) shared across colors; Gold P-Chips raise it; color swaps keep it
- Stackable sub-systems: Drones (≤2 orbiting auto-turrets, lost on hit), Speed (≤3 stacks)
- Rare utilities: hit-based Shield (≤2 charges), stocked Bombs (≤3), Energy (~4s fire-rate + invuln)
- Recovery: volcano Power Orbs on death, stage power floor on respawn, death-bomb panic window
- `play_victory_exit()` cinematic on stage clear
- 3 ships per run; Bomb input: B / Shift / on-screen button

## UI

HUD chrome is driven by existing `EventBus` signals (`score_changed`, `player_lives_changed`, `weapon_tier_changed`, `player_hp_changed`, `bomb_stock_changed`, `overdrive_changed`). Do not invent a parallel data path.

Pause (Esc / Start / on-screen button) emits `EventBus.pause_requested`. `GameWorld` toggles the tree pause flag and shows `PauseMenu`. **Settings** instances `settings_menu.tscn` as a child overlay (`overlay_mode = true`) so the run stays loaded — never `change_scene` to settings from pause.

| Scene | Purpose |
|-------|---------|
| `main_menu.tscn` | Campaign / Boss Rush / Settings / Quit |
| `campaign_select.tscn` | Unlockable 1-1 … 2-5 list |
| `hud.tscn` | Lives, HP, weapon badge + chips, score, boss bar, overdrive, toasts, Bomb / Pause |
| `pause_menu.tscn` | Resume / Settings overlay / main menu (`PROCESS_MODE_ALWAYS`) |
| `settings_menu.tscn` | Volumes + accessibility; overlay or standalone |
| `mission_results.tscn` | Win/lose summary |

## Display

- Base viewport 480×720, portrait
- Stretch: `canvas_items` + `aspect=expand` (fills modern phone screens)
- Android export: immersive mode enabled in `export_presets.cfg`

## Tests / CI

Headless scripts under `tools/`:

- `validate_project.gd` — scenes, missions, archetypes, sprites, gimmick modules, HUD signals
- `test_player.gd` — ship facade + WeaponSystem / LifeSystem
- `smoke_test.gd` — boots 1-1 and 2-1 briefly
- `smoke_boss_rush.gd` — first raid boss must spawn and fire

GitHub Actions (`.github/workflows/ci.yml`) runs the same set. Locally: `nix shell nixpkgs#godot --command ./tools/ci.sh`.

`--script` tools that need autoloads (`GameState`, `AudioBus`, `EventBus`) should `call_deferred` after a frame rather than work in `_init`. Refresh the class cache with `godot --headless --path . --editor --quit-after 1` (`--import` does not). SceneTree tools should duck-type gimmick modules (`bind` / `begin` / `tick` / `cleanup`) instead of `is StageGimmick`.

## Extension points

**New sector:** add mission `.tres` paths (or generate them), append to `GameState.MISSION_PATHS` / sector constants, add music entries in `AudioBus.MISSION_MUSIC`. Unique loops need original audio in `assets/audio/`; do not generate placeholder music.

**New gimmick:** add `scripts/stage/gimmicks/<id>.gd` extending `"res://scripts/stage/gimmicks/stage_gimmick.gd"`, register it in `StageDirector.GIMMICKS`, set `MissionData.gimmick_id` in the generator.

**New boss:** one `boss_archetype` value in `generate_resources.gd` + a branch in `boss_patterns.gd` + optional SVG in `enemy_base.gd` sprite maps. Then regenerate `.tres`. Never string-match `display_name`.