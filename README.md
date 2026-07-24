# Nebula Dawn

Vertical-scrolling space shooter built with **Godot 4.7** (GDScript).

Campaign has two sectors (ten stages) with unique gimmicks. An Endless survival mode is also included. Built for desktop and Android (portrait).

---

## Quick start

### Requirements

- [Godot 4.3+](https://godotengine.org/) (4.7 recommended)
- Optional (Android): Android SDK, debug keystore, `adb`

### Run (desktop)

```bash
godot --path .
```

Or open this folder in the Godot editor and press Play.

### Build Android APK

```bash
nix shell nixpkgs#godot --command ./scripts/build_apk.sh
```

Exports a signed debug APK to `build/NebulaDawn-debug.apk` (does not install). Install separately with `adb install -r build/NebulaDawn-debug.apk` if needed.

---

## Controls

| Action | Touch | Keyboard | Gamepad |
|--------|-------|----------|---------|
| Move | Drag — ship mirrors finger motion from where you grabbed | WASD / Arrow keys | Left stick / D-pad |
| Fire | Auto | Auto | Auto |
| Pause | — | Esc | Start |

Fire is always on. Weapons and power-ups change *what* you shoot, not whether you shoot.

---

## Game modes

### Sector 1 (campaign)

Five stages. Clear a stage to unlock the next. Progress is saved under `user://nebula_dawn.cfg`.

| Code | Stage | Gimmick |
|------|--------|---------|
| **1-1** | Planetary Ascent | Clear a whole formation → chain reaction (nearby enemy bullets wiped + bonus pickup) |
| **1-2** | The Asteroid Belt | Large asteroids split when destroyed; rocks block enemy bullets |
| **1-3** | Nebula Anomaly | Fog pulses + plasma pools (+50% damage, secondaries disabled while inside) |
| **1-4** | Cybernetic Hive | Sweeping laser barriers; shoot terminals to shut them down |
| **1-5** | Flagship Core | Singularities pull ship/bullets; graze them to fill **Overdrive** (brief slow-mo) |

Beating stages 1–4 shows **STAGE CLEARED** with a statistics screen, letter rank (S/A/B/C), and a **Next Mission** button. Beating Flagship Core shows **SECTOR 1 CLEARED** and unlocks Sector 2.

### Sector 2 (campaign)

Unlocked after Flagship Core. Denser EX-style power floor (Lv2 + Bomb/Shield on respawn).

| Code | Stage | Gimmick |
|------|--------|---------|
| **2-1** | Mirror Field | Mirror plates bounce enemy bullets sideways |
| **2-2** | Ion Storm | Vertical lightning columns pulse across lanes |
| **2-3** | Phantom Wake | Fog + delayed echo volleys at your last position |
| **2-4** | Scrap Gauntlet | Horizontal scrap conveyors shove the ship |
| **2-5** | Dawn Gate | Solar flares scorch the lower field; residual gravity wells |

### Endless

Continuous enemy waves with a rising difficulty curve. No win condition — survive for score. Best score is persisted.

---

## Stage structure (every campaign stage)

Each stage runs about **seven scripted waves** plus the stage boss:

1. **Opener / Sweep** — popcorn & readable patterns (hybrid ~14s)
2. **Escalation / Pressure** — denser mixed threats (hybrid ~16s)
3. **Mid-Boss** — must kill; drops a P-Chip + one rare utility (Shield / Bomb / Energy / Heal)
4. **Build** — recover into heavier setups (hybrid ~16s)
5. **Climax** — peak stage chaos (hybrid ~20s)
6. **Stage Boss** — multi-phase boss after all waves

**Hybrid wave clear:** the next wave starts when this wave’s enemies are dead **or** a max timer expires (whichever first). Mid-bosses have no timeout.

On a **win**, the ship glides to screen center, hovers, then streaks off-screen before the results UI.

---

## Combat & power-ups

### Color-coded weapons + universal power

Weapon **type** and **power level** are tracked separately.

| Color | Pickup | Weapon | Behavior |
|-------|--------|--------|----------|
| **Red** | Spread | Wide cone | Lv1 3-way → Lv2 5-way + ROF → Lv3 7-way + side-cancellation waves |
| **Blue** | Laser | Focused beam | Lv1 single → Lv2 dual + armor pierce → Lv3 mega beam + melt ticks |
| **Green** | Homing | Seeking missiles | Lv1 2 slow → Lv2 4 fast micro → Lv3 6 rapid + splash |

**Gold P-Chips** fill a **5-segment** bar toward the next shared tier (**Lv1 → Lv2 → Lv3 / MAX**). Swapping color keeps both tier and chip progress. Same color again also banks a chip. Hull damage resets to Blaster (tier + chips lost) but keeps Bits and Speed.

### Recovery (deaths)

| Mechanic | Effect |
|----------|--------|
| **Volcano Drop** | On ship loss, 3–4 large Power Orbs scatter and drift down. Sweep them during ~2.5s respawn invuln to rebuild ~50–75% of peak power. |
| **Power Floor** | Stages 1–3 respawn at Lv1; stages 4–5 at Lv2; EX (6–10) at Lv2 + a free Bomb or Shield. |
| **Death-Bomb** | If you hold a bomb, ~0.25s after a lethal hit you can press Bomb to cancel death, wipe the screen, and survive at 1 HP. |

You start with **3 ships**. Bombs are stocked (max 3) from Bomb pickups — press **B** / **Shift** or the on-screen BOMB button.

### Sub-system upgrades

| Pickup | Effect | Cap |
|--------|--------|-----|
| P-Chip (Gold) | Raises shared power tier | Lv 3 |
| Bit | Orbiting option drone (mirrors fire or seeks) | 2 |
| Speed | +12% move speed per stack | 3 |

### Rare utility drops

Kept sparse so they feel valuable. Mid-bosses always drop one; a **full wave wipe** (not a timeout) has a ~40% chance of another.

| Pickup | Effect |
|--------|--------|
| Shield / Barrier | Absorbs up to 2 hits before breaking |
| Bomb / Smart Cleaver | Clears non-boss bullets on screen + heavy burst damage |
| Energy / Overdrive | ~4s fire-rate boost and invulnerability |
| Heal | +1 HP (mid-boss pool only) |

---

## World layers

Scrolling depth (ratios relative to playfield `scroll_speed`):

| Layer | Speed | Role |
|-------|-------|------|
| Far background | 0.1× | Nebula, stars, planet horizons |
| Midground | 0.5× | Stations, terrain, capital silhouettes |
| Playfield grid | 1.0× | Combat plane (player, enemies, bullets) |
| Foreground | 1.5× | Debris / wisps drawn over the ship |

Mission `background_tint` and `scroll_speed` drive the look per stage.

---

## Music

| Context | Track |
|---------|--------|
| Menu | `Menu.mp3` |
| 1-1 | `Interceptor_Run.mp3` |
| 1-2 | `Against_the_Solar_Wind.mp3` |
| 1-3 | `Zero_G_Intercept.mp3` |
| 1-4 | `Hull_Breach_Protocol.mp3` |
| 1-5 | `Gravity_Override.mp3` |
| 2-1 | `Orbital_Strike_Pattern.mp3` |
| 2-2 | `Against_the_Solar_Wind.mp3` |
| 2-3 | `Zero_G_Intercept.mp3` |
| 2-4 | `Hull_Breach_Protocol.mp3` |
| 2-5 | `Last_Sector_Approach.mp3` |
| Endless | `Last_Sector_Approach.mp3` |

Sampled SFX live in `assets/audio/sfx/`. Mapping is in `scripts/autoloads/audio_bus.gd`.

---

## Project layout

```
nebula-dawn/
├── assets/
│   ├── audio/          # Menu + stage MP3s
│   └── sprites/        # Enemy + pickup art
├── resources/
│   ├── enemies/        # Shared EnemyStats .tres
│   └── missions/       # Sector 1 stage definitions
├── scenes/
│   ├── entities/       # Player, enemies, projectiles, pickups
│   ├── game/           # GameWorld, HUD, parallax, pause
│   ├── stage/          # Barriers, terminals, singularities
│   └── ui/             # Main menu, sector select, results
├── scripts/
│   ├── autoloads/      # GameState, AudioBus, EventBus
│   ├── combat/         # Projectile pool
│   ├── enemies/        # Enemy + pickup logic
│   ├── game/           # World + parallax
│   ├── mission/        # Waves, runner, formations
│   ├── player/         # Ship + weapons
│   ├── stage/          # StageDirector + gimmicks
│   ├── ui/
│   └── build_apk.sh
├── tools/              # Resource generator + smoke tests
├── export_presets.cfg  # Android export
└── project.godot
```

### Autoloads

| Name | Role |
|------|------|
| `GameState` | Mode, mission index, unlocks, scores, save/load |
| `AudioBus` | Procedural SFX + looping music |
| `EventBus` | Decoupled gameplay signals (HP, waves, boss, gimmicks, …) |

### Authoring missions

Stage content is generated from `tools/generate_resources.gd` into `.tres` files:

```bash
godot --headless --path . --script res://tools/generate_resources.gd
```

Edit the `_mission_0N(...)` helpers (waves, enemies, gimmick id, tint, scroll), then regenerate. Do not hand-edit large embedded `.tres` blobs unless you know you need to.

Key data types:

- `MissionData` — title, sector/stage, waves, boss, `gimmick_id`, tint, scroll
- `WaveDef` — label, entries, `clear_required`, `max_clear_time`
- `SpawnEntry` — enemy, delay, position, count, spacing, optional `formation_id`
- `EnemyStats` — HP, speed, fire rate, flags (`is_hazard`, `is_boss`, `is_mid_boss`)

### Validation / smoke tests

```bash
godot --headless --path . --script res://tools/validate_project.gd
godot --headless --path . --script res://tools/smoke_test.gd
godot --headless --path . --script res://tools/smoke_endless.gd
```

---

## Further reading

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — systems, flow, collision layers
- [docs/DESIGN.md](docs/DESIGN.md) — Sector 1 design notes and gimmick intent

---

## License / notes

Game code and generated resources are part of this repository. Audio and sprite assets under `assets/` should be treated according to their source licenses if redistributed.