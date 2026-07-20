# Nebula Dawn

Vertical-scrolling space shooter built with **Godot 4.7** (GDScript). Campaign missions first; Endless mode included.

## Run

1. Install [Godot 4.3+](https://godotengine.org/) (4.7 recommended).
2. Open this folder in the Godot editor, or from a terminal:

```bash
godot --path .
```

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | WASD / Arrows | Left stick / D-pad |
| Fire | Auto | — |
| Pause | Esc | Start |

## Campaign

1. **Dawn Patrol** — intro scouts and strafers  
2. **Debris Field** — asteroids + mixed fighters  
3. **Nebula Core** — elites, then the boss  

Missions and enemy stats live under `resources/` as `.tres` files. Regenerate with:

```bash
godot --headless --path . --script res://tools/generate_resources.gd
```

## Project layout

- `scenes/game/` — shared `GameWorld` (campaign + endless)
- `scenes/ui/` — menus and results
- `scripts/mission/` — mission data, wave spawner, runner
- `scripts/combat/` — projectile pooling
- `resources/missions/` — wave definitions
