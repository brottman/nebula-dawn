class_name WaveDef
extends Resource
## A timed group of enemy spawns.

@export var label: String = "Wave"
@export var start_delay: float = 0.5
@export var entries: Array[SpawnEntry] = []
## If true, wait for this wave's enemies to die before continuing.
@export var clear_required: bool = true
## Hybrid clear: also advance when this many seconds pass after spawning finishes.
## Set to 0 to require a full clear (mid-boss / must-kill beats).
@export var max_clear_time: float = 8.0
