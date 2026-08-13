# Architecture

Technical overview of Nebula Dawn’s runtime systems.

## High-level flow

```
MainMenu
  ├─ Campaign → GameWorld (campaign mission)
  └─ Boss Rush → GameWorld (raid arenas)

GameWorld
  ├─ ParallaxBg          # 4 scroll layers
  ├─ Player              # touch / keyboard ship
  ├─ Entities            # enemies, hazards, stage props
  ├─ Projectiles         # pooled bullets
  ├─ WaveSpawner         # campaign waves
  ├─ MissionRunner       # win / lose
  ├─ FormationTracker    # Stage 1 chain reactions
  ├─ StageDirector       # per-mission gimmick runtime
  ├─ HUD / PauseMenu
  └─ on win → victory exit tween → MissionResults
```

## Campaign progression

1. `GameState.start_campaign_mission(index)` sets mode + mission index and clears session score.
2. `GameWorld` loads `MissionData` from `GameState.MISSION_PATHS`.
3. `StageDirector.begin(data)` enables the gimmick module (`gimmick_id`).
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
- Boss fire phases by HP ratio (1-way → 3-way → 5-way)
- Mid-boss: `is_boss` + `is_mid_boss` — uses boss HUD, does **not** end the mission
- Asteroids: split into smaller tiers on death; `absorb_bullet` for blocked enemy shots
- Sprites from `assets/sprites/` with light color modulate for variants

## Stage gimmicks (`StageDirector`)

| `gimmick_id` | Runtime behavior |
|--------------|------------------|
| `formations` | Handled by `FormationTracker` (no director loop required) |
| `asteroids` | Toast only; split/block is in enemy/projectile code |
| `nebula` | Fog overlay + drifting plasma `Area2D`s (`enter_plasma` / `exit_plasma` on player) |
| `hive` | Spawns barrier pairs + terminals on a pulse timer |
| `gravity` | Spawns singularities; pulls player + bends enemy bullets; graze fills Overdrive |

## Player

`player_ship.gd`:

- Touch-follow or keyboard 8-way
- Auto-fire weapon system: stock Blaster + color weapons (Red Spread / Blue Laser / Green Homing)
- Universal power tier (Lv1–3) shared across colors; Gold P-Chips raise it; color swaps keep it
- Stackable sub-systems: Drones (≤2 orbiting auto-turrets, lost on hit), Speed (≤3 stacks)
- Rare utilities: hit-based Shield (≤2 charges), stocked Bombs (≤3), Energy (~4s fire-rate + invuln)
- Recovery: volcano Power Orbs on death, stage power floor on respawn, death-bomb panic window
- Plasma zone flags, Overdrive meter
- `play_victory_exit()` cinematic on stage clear
- 3 ships per run; Bomb input: B / Shift / on-screen button

## UI

| Scene | Purpose |
|-------|---------|
| `main_menu.tscn` | Campaign / Boss Rush / Quit |
| `campaign_select.tscn` | Unlockable 1-1 … 1-5 list |
| `hud.tscn` | Act label, boss bar, overdrive, toasts |
| `pause_menu.tscn` | Resume / main menu (`PROCESS_MODE_ALWAYS`) |
| `mission_results.tscn` | Win/lose summary |

## Display

- Base viewport 480×720, portrait
- Stretch: `canvas_items` + `aspect=expand` (fills modern phone screens)
- Android export: immersive mode enabled in `export_presets.cfg`

## Extension points

**New sector:** add mission `.tres` paths (or generate them), append to `GameState.MISSION_PATHS` / sector constants, add music entries in `AudioBus.MISSION_MUSIC`.

**New gimmick:** add a `gimmick_id` branch in `StageDirector`, optional new scenes under `scenes/stage/`, set `MissionData.gimmick_id` in the generator.

**New enemy archetype:** extend `EnemyStats` + visuals in `enemy_base._apply_visuals` / sprite map; reference from generator catalog.
