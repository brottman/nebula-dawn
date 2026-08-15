# Architecture

Technical overview of Nebula Dawn’s runtime systems.

## High-level flow

```
MainMenu
  ├─ Campaign → CampaignSelect → GameWorld (campaign mission)
  ├─ Hangar                  # buy / equip / upgrade hulls
  ├─ Settings (standalone scene)
  └─ Boss Rush → GameWorld (raid arenas)

Hangar is also reachable from CampaignSelect and MissionResults.
Each entry sets GameState.hangar_return_scene, then change_scene to hangar.tscn.

GameWorld
  ├─ ParallaxBg          # 4 scroll layers
  ├─ Player              # apply_hangar_loadout, then WeaponSystem / LifeSystem
  ├─ Entities            # enemies, hazards, stage props
  ├─ Projectiles         # pooled bullets
  ├─ WaveSpawner         # campaign waves
  ├─ MissionRunner       # win / lose
  ├─ FormationTracker    # Stage 1 chain reactions
  ├─ StageDirector       # loads one StageGimmick by gimmick_id
  ├─ HUD                 # lives / score / weapon / Power via EventBus
  ├─ PauseMenu           # Settings overlay (run stays loaded)
  └─ on win → victory exit tween → MissionResults
        └─ Hangar (return to MissionResults)
```

## Campaign progression

1. `GameState.start_campaign_mission(index)` sets mode + mission index and clears session score.
2. `GameWorld` loads `MissionData` from `GameState.MISSION_PATHS`.
3. `StageDirector.begin(data)` instantiates the gimmick module (`gimmick_id`).
4. `MissionRunner.begin_campaign(data)` starts `WaveSpawner`.
5. Waves advance via **hybrid clear** (all *this wave’s* enemies dead **or** `max_clear_time`).
6. After waves: optional Act 5 boss (`MissionData.boss`).
7. `MissionRunner` records result → `GameWorld` plays victory outro (if won) → results scene.

Unlocks: clearing stage *N* unlocks *N+1* (`highest_unlocked_mission`). Campaign, Boss Rush, settings, and hangar all persist in `user://nebula_dawn.cfg`.

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

## Hangar

Meta-progression is **credits and strike craft**, not a player XP / account level. In-run weapon power stays gold Power pickups (**Lv1–3**). `GameState.Ships` preloads `scripts/hangar/ship_catalog.gd`.

### Scene flow

`hangar.tscn` is a standalone UI. Entry points set `GameState.hangar_return_scene` then `change_scene` to the hangar:

| From | `hangar_return_scene` |
|------|------------------------|
| Main menu | `scenes/ui/main_menu.tscn` |
| Campaign select | `scenes/ui/campaign_select.tscn` |
| Mission results | `scenes/ui/mission_results.tscn` |

Back uses that path (empty string falls back to the main menu). Default is `main_menu.tscn`.

### Persist

Same `user://nebula_dawn.cfg` as campaign progress:

- `[hangar]` — `credits`, `selected`, `owned` (comma-separated hull ids)
- `[upgrades]` — per hull id → `"hull,thrust,cannon,core"` ranks

`GameState.load_progress()` calls `_load_hangar`. Saves **without** a `[hangar]` section seed credits from `best_scores` plus `boss_rush_high_score` (`ShipCatalog.credits_from_score` = `score / 10`), then `save_progress()`. `_ensure_hangar()` always keeps Striker owned and a valid selected hull.

`buy_ship` / `select_ship` / `buy_upgrade` write immediately. `reset_hangar()` is for tests only.

### Catalog and loadout

`ShipCatalog` owns the roster, `resolve(id, ranks)`, upgrade costs, and `format_credits`. Hulls: `striker` (free starter), `interceptor` 2500, `aegis` 5500, `wraith` 12000, `dawn` 24000. Per-hull upgrades `hull` / `thrust` / `cannon` / `core`, ranks 0–5, costs `[400, 900, 1600, 2600, 4000]`. Effects: **+1 HP**, **+5% speed**, **+8% damage**, **+4% fire rate**. Fire cooldown is clamped to `MIN_FIRE_COOLDOWN` (0.08). All hulls share the 30×32 collision box; hangar portraits are 480×720.

Every finished run (win or loss) banks credits in `record_mission_result` via `_award_run_credits` (`session_score / 10`). Results shows `CREDITS  +X    ·    bank  Y` from `last_credits_earned` and `credits`.

## Player

`player_ship.gd` is the public facade (`hp`, `lives`, `apply_pickup`, `try_use_bomb`, `_emit_weapon_changed`, `_try_death_bomb`, `_death_bomb_time`, …). HUD / GameWorld / pickups still call the ship; `WeaponSystem` and `LifeSystem` are child nodes in `player.tscn`.

On `_ready`, `apply_hangar_loadout()` copies `GameState.get_active_loadout()` onto the ship (HP, speed, fire cooldown, damage, sprite, `_ship_tint`). Then `LifeSystem.reset_run()` takes lives / starting bombs / shields from that spec. `WeaponSystem` scales each weapon CD by `ship.fire_cooldown / ShipCatalog.BASE_FIRE_COOLDOWN` (0.16), clamped to `MIN_FIRE_COOLDOWN`. Respawn restores `_ship_tint`.

- `WeaponSystem` — color weapons, shared power tier, drones, speed; hull fire-rate scaling
- `LifeSystem` — hull, lives, shields, bombs, death/respawn, volcano drop, Overdrive, plasma
- Touch-follow or keyboard 8-way
- Auto-fire: stock Blaster + color weapons (Red Spread / Blue Laser column / Green Homing)
- Color pickups unlock that family; Q / Tab / X / HUD WEP cycles among unlocked colors
- Universal power tier (Lv1–3) shared across colors; Gold P-Chips raise it; color swaps keep it
- Hull hits drop to Blaster and clear the color rack; Bits/Speed persist
- Stackable sub-systems: Drones (≤2 orbiting auto-turrets, lost on hit), Speed (≤3 stacks)
- Rare utilities: hit-based Shield (≤2 charges), stocked Bombs (≤3), Energy (~4s fire-rate + invuln)
- Recovery: volcano Power Orbs on death, stage power floor on respawn, death-bomb panic window
- `play_victory_exit()` cinematic on stage clear
- Starting lives come from the equipped hull (Striker: 3); Bomb input: B / Shift / on-screen button; weapon switch: Q / Tab / X / WEP

## UI

HUD chrome is driven by existing `EventBus` signals (`score_changed`, `player_lives_changed`, `weapon_tier_changed`, `player_hp_changed`, `bomb_stock_changed`, `overdrive_changed`). Do not invent a parallel data path.

Pause (Esc / Start / on-screen button) emits `EventBus.pause_requested`. `GameWorld` toggles the tree pause flag and shows `PauseMenu`. **Settings** instances `settings_menu.tscn` as a child overlay (`overlay_mode = true`) so the run stays loaded — never `change_scene` to settings from pause.

| Scene | Purpose |
|-------|---------|
| `main_menu.tscn` | Campaign / Hangar / Boss Rush / Settings / Quit; shows bank + equipped hull |
| `hangar.tscn` | Buy / equip hulls; rank Hull / Thrusters / Cannons / Core |
| `campaign_select.tscn` | Unlockable 1-1 … 2-5 list; Hangar + equipped name / credits |
| `hud.tscn` | Lives, HP, weapon badge + Power bar, score, boss bar, overdrive, toasts, Bomb / WEP / Pause |
| `pause_menu.tscn` | Resume / Settings overlay / main menu (`PROCESS_MODE_ALWAYS`) |
| `settings_menu.tscn` | Volumes + accessibility; overlay or standalone |
| `mission_results.tscn` | Win/lose summary; credits earned / bank; Hangar |

## Display

- Base viewport 480×720, portrait
- Stretch: `canvas_items` + `aspect=expand` (fills modern phone screens)
- Android export: immersive mode enabled in `export_presets.cfg`

## Tests / CI

Headless scripts under `tools/`:

- `validate_project.gd` — scenes, missions, archetypes, sprites, gimmick modules, HUD signals, hangar catalog/UI
- `test_hangar.gd` — catalog, buy/upgrade, run credits, old-save seed, player loadout (stashes `user://nebula_dawn.cfg` to `user://nebula_dawn.cfg.hangar_test.bak`; if the stash fails it must not delete the live save)
- `test_player.gd` — ship facade + WeaponSystem / LifeSystem (`reset_hangar()` first)
- `smoke_test.gd` — boots 1-1 and 2-1 briefly
- `smoke_boss_rush.gd` — first raid boss must spawn and fire

GitHub Actions (`.github/workflows/ci.yml`) runs the same set. Locally: `nix shell nixpkgs#godot --command ./tools/ci.sh`. `tools/ci.sh` treats a `SCRIPT ERROR` in Godot output as failure — `--script` often still exits 0 on compile errors.

`--script` tools that need autoloads (`GameState`, `AudioBus`, `EventBus`) should `call_deferred` after a frame rather than work in `_init`, and must not use those names as compile-time identifiers (use `root.get_node_or_null("GameState")`). Refresh the class cache with `godot --headless --path . --editor --quit-after 1` (`--import` does not). SceneTree tools should duck-type gimmick modules (`bind` / `begin` / `tick` / `cleanup`) instead of `is StageGimmick`.

## Extension points

**New sector:** add mission `.tres` paths (or generate them), append to `GameState.MISSION_PATHS` / sector constants, add music entries in `AudioBus.MISSION_MUSIC`. Unique loops need original audio in `assets/audio/`; do not generate placeholder music.

**New gimmick:** add `scripts/stage/gimmicks/<id>.gd` extending `"res://scripts/stage/gimmicks/stage_gimmick.gd"`, register it in `StageDirector.GIMMICKS`, set `MissionData.gimmick_id` in the generator.

**New boss:** one `boss_archetype` value in `generate_resources.gd` + a branch in `boss_patterns.gd` + optional SVG in `enemy_base.gd` sprite maps. Then regenerate `.tres`. Never string-match `display_name`.