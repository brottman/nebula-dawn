# Design — Sector 1

Design intent for Nebula Dawn’s opening sector. Implementation details live in [ARCHITECTURE.md](ARCHITECTURE.md) and `tools/generate_resources.gd`.

## Fantasy

You are a strike craft punching through enemy-held space: low orbit, debris fields, a living nebula, an automated shipyard, and finally the flagship core. Each stage teaches one idea hard, then the finale asks you to combine them under pressure.

## Sector 1 stage briefs

### 1-1 Planetary Ascent

- **Setting:** Leaving a futuristic metropolis into low orbit.
- **Threats:** Fast interceptors, light defense drones.
- **Teach:** Shooting, movement, pickups; reward aggression.
- **Gimmick:** Predictable formations. Wipe a whole formation before it escapes for a **chain reaction** (clear nearby enemy bullets + bonus power-up).
- **Mid-boss:** Heavy Transport (side pressure).
- **Boss:** Orbital Defense Platform — rotating armor teaches strafing for weak angles.

### 1-2 The Asteroid Belt

- **Setting:** Mining debris and ice rocks.
- **Threats:** Mining drones, armored cruisers, unguided rocks.
- **Teach:** Spatial awareness and precision.
- **Gimmick:** Large asteroids **split** into faster fragments. Rocks **block enemy bullets** — use them as cover, or shatter them and eat chaos.
- **Mid-boss:** Seismic Drill.
- **Boss:** Megalith Dreadnought — heavy, wide patterns; arena still has rock traffic.

### 1-3 Nebula Anomaly

- **Setting:** Glowing volatile gas cloud.
- **Threats:** Bio-ships, stealth craft.
- **Teach:** Micro-dodging and weapon choice under interference.
- **Gimmick:** Periodic **fog** over the lower field. **Plasma pools** boost primary damage (~50%) but disable secondary weapons while you’re inside.
- **Mid-boss:** Quantum Stalker — teleports with little warning.
- **Boss:** Celestial Leviathan — dense ethereal bullet work (illusions can be deepened later).

### 1-4 Cybernetic Hive

- **Setting:** Orbital shipyard / factory fleet.
- **Threats:** Repair drones, heavy turrets, invulnerable fence segments.
- **Teach:** Area denial and reading safe corridors.
- **Gimmick:** Sweeping **energy barriers**. **Terminals** you can shoot disable nearby fences and clear local bullets.
- **Mid-boss:** Core Overseer.
- **Boss:** Fabrication Matrix — keeps spawning sub-drones; split DPS between core and adds.

### 1-5 Flagship Core

- **Setting:** Deep-space command fleet around the super-weapon.
- **Threats:** Ace fighters, capital pressure, high-density patterns.
- **Teach:** Bullet-hell reading + risk/reward.
- **Gimmick:** **Singularities** pull the ship and warp enemy bullets. **Graze** the well to charge **Overdrive** (short slow-motion window).
- **Mid-boss:** Twin Ace Lead (paired pressure).
- **Boss:** Omega Engine — peak density; gravity still in play.

## Screen layout

```
TOP HUD BAR (static)     HP/Lives  |  Weapon badge + LV + 5 Power segments  |  Score
PLAYFIELD                Active action zone (no chrome)
BOTTOM TOUCH             Bomb button (tap) — bottom-left corner
```

Top-center weapon module:

```
[RED] SPREAD BEAM              [ LV 2 ]
[■][■][■][□][□]           3/5 POWER
```

Badge color = weapon family. Segments show Power banked toward the next tier (instant “I need 2 more”).

## Color weapons + universal power

Weapon type and power level are independent:

| Color | Weapon | Lv1 | Lv2 | Lv3 |
|-------|--------|-----|-----|-----|
| **Red** | Spread | 3-way fan | 5-way + faster ROF | 7-way + side-cancellation waves |
| **Blue** | Laser | Solid piercing column | Wider column + armor pierce | Mega column + melt ticks |
| **Green** | Homing | 2 slow rockets | 4 fast micro-missiles | 6 rapid + splash |

**Gold Power** pickups fill 5 segments toward the next shared tier (Lv1 → Lv2 → Lv3 / MAX), including while you are on Blaster. Color pickups unlock that family for the life; **Q / Tab / X / WEP** cycles among unlocked colors (shared tier stays). Same-color pickups — or a color you already unlocked — also bank Power. Hull hits drop you to Blaster and clear the rack.

### Recovery on death

- **Volcano Drop:** 3–4 large Power Orbs scatter on ship loss; collect during respawn invuln to rebuild ~50–75% of peak power.
- **Power Floor:** Stages 1–3 → respawn Lv1; 4–5 → Lv2; EX 6–10 → Lv2 + Bomb or Shield charge.
- **Death-Bomb:** ~0.25s panic window on lethal damage — spend a stocked bomb to cancel death and clear the screen.

## Rare defensive / utility drops

Common fodder only drops weapons and stackables (Power / Bit / Speed). Defensive utilities stay rare:

| Drop | Effect | Sources |
|------|--------|---------|
| **Shield** | Hit-based barrier (up to 2 charges) | Mid-boss reward, full wave wipe (~40%) |
| **Bomb** | Wipe enemy bullets + burst damage (stage bosses only chip) | Mid-boss reward, full wave wipe |
| **Energy** | ~4s fire-rate boost + invulnerability | Mid-boss reward, full wave wipe |
| **Heal** | +1 HP | Mid-boss reward pool only |

Formation chain bonuses stay common (Power / Bit) — they are aggression rewards, not panic buttons.

## Pacing rules of thumb

| Act | Feel | Clear rule |
|-----|------|------------|
| Opener (+ Sweep/Drift) | Warm-up, readable paths | Hybrid ~14s |
| Escalation (+ Pressure) | Force movement | Hybrid ~16s |
| Mid-boss | Focus fire, then reward | Must kill |
| Build | Recover into denser setups | Hybrid ~16s |
| Climax | Peak stage chaos | Hybrid ~20s |
| Stage boss | Exam on this stage’s lesson | Defeat boss |

Each campaign stage now runs about **7 scripted waves** before the boss (was 4), so a clear typically lands in the multi-minute range rather than a short sprint.

Victory outro (center → hover → zoom off) sells the “sortie complete” beat before stats.

## Audio identity

Each stage has a looping track (see README). Menu and Boss Rush use dedicated themes so campaign stages keep a distinct musical memory. 2-2 / 2-3 / 2-4 reuse Sector 1 originals until unique source MP3s exist — do not generate placeholder loops.

## Visual identity

- Hand-authored vector sprites (SVG, imported by Godot) for enemy archetypes, the player ship, and pickups (`assets/sprites/`). Enemy art is grayscale so the per-mission `stats.color` tint reads clearly; the player ship carries its own palette. Sector 2 stage bosses and mid-bosses (plus 1-1 Heavy Transport) have unique hulls keyed by `boss_archetype`; Sector 1 stage bosses still reuse the generic boss hull.
- Soft modulate tints differentiate mission variants that reuse an archetype.
- Four parallax layers keep speed readable even when the playfield is busy.

## Future sectors

Sector 2 is implemented as missions 2-1…2-5 (`mirrors`, `ion`, `phantoms`, `scrap`, `flare`). Later sectors can keep appending mission paths, music, and `gimmick_id` modules without rewriting the runner. Prefer new stage modules over growing `enemy_base.gd` forever.