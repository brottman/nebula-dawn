class_name SpawnEntry
extends Resource
## One enemy spawn within a wave.

@export var enemy: EnemyStats
@export var delay: float = 0.0
@export var position: Vector2 = Vector2(240, -40)
@export var count: int = 1
@export var spacing: Vector2 = Vector2(40, 0)
## Non-empty = all units in this entry share a formation for chain-reaction clears.
@export var formation_id: String = ""
