class_name WaveDef
extends Resource
## A timed group of enemy spawns.

@export var label: String = "Wave"
@export var start_delay: float = 0.5
@export var entries: Array[SpawnEntry] = []
@export var clear_required: bool = true
