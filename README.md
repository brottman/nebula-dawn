# Nebula Dawn

Vertical-scrolling space shooter built with **Godot 4.7** (GDScript). Five thematic campaign stages; Endless mode included.

## Run

1. Install [Godot 4.3+](https://godotengine.org/) (4.7 recommended).
2. Open this folder in the Godot editor, or from a terminal:

```bash
godot --path .
```

## Controls

| Action | Touch | Keyboard | Gamepad |
|--------|-------|----------|---------|
| Move | Drag finger — ship follows | WASD / Arrows | Left stick / D-pad |
| Fire | Auto | Auto | Auto |
| Pause | — | Esc | Start |

## Campaign (Sector 1)

Five stages from low orbit to the Flagship Core:

1. **1-1 Planetary Ascent** — formation chain-reactions
2. **1-2 The Asteroid Belt** — splitting rocks that block bullets
3. **1-3 Nebula Anomaly** — fog + plasma weapon boosts
4. **1-4 Cybernetic Hive** — laser fences & shootable terminals
5. **1-5 Flagship Core** — singularities, graze Overdrive

Each stage: Opener → Escalation → Mid-Boss → Climax → Stage Boss.

Regenerate mission data with:

```bash
godot --headless --path . --script res://tools/generate_resources.gd
```

## Project layout

- `scenes/game/` — shared `GameWorld` (campaign + endless)
- `scenes/stage/` — barriers, terminals, singularities
- `scripts/stage/` — StageDirector + gimmick entities
- `scripts/mission/` — mission data, wave spawner, formation tracker
- `resources/missions/` — five campaign stages
