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

## Color weapons + universal power

Weapon type and power level are independent:

| Color | Weapon | Lv1 | Lv2 | Lv3 |
|-------|--------|-----|-----|-----|
| **Red** | Spread | 3-way fan | 5-way + faster ROF | 7-way + side-cancellation waves |
| **Blue** | Laser | Single beam | Dual beams + armor pierce | Mega beam + melt ticks |
| **Green** | Homing | 2 slow rockets | 4 fast micro-missiles | 6 rapid + splash |

**Gold P-Chips** raise a shared tier from Lv1 → Lv2 → Lv3. Grabbing a different color keeps that tier (Lv3 Spread + Blue = Lv3 Laser). Same-color pickups also power up. Hull hits drop you to Blaster Lv1.

## Rare defensive / utility drops

Common fodder only drops weapons and stackables (P-Chip / Bit / Speed). Defensive utilities stay rare:

| Drop | Effect | Sources |
|------|--------|---------|
| **Shield** | Hit-based barrier (up to 2 charges) | Mid-boss reward, full wave wipe (~40%) |
| **Bomb** | Wipe enemy bullets + burst damage (stage bosses only chip) | Mid-boss reward, full wave wipe |
| **Energy** | ~4s fire-rate boost + invulnerability | Mid-boss reward, full wave wipe |
| **Heal** | +1 HP | Mid-boss reward pool only |

Formation chain bonuses stay common (P-Chip / Bit) — they are aggression rewards, not panic buttons.

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

Each stage has its own looping track (see README). Menu and Endless use dedicated themes so campaign stages keep a distinct musical memory.

## Visual identity

- Illustrated sprites for core enemy archetypes and pickups (`assets/sprites/`).
- Soft modulate tints differentiate mission variants that reuse an archetype.
- Four parallax layers keep speed readable even when the playfield is busy.

## Future sectors (not implemented)

Sector 1 is structured so later sectors can append mission paths, music, and `gimmick_id` modules without rewriting the runner. Prefer new stage modules over growing `enemy_base.gd` forever.
