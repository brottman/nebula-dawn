class_name EnemyStats
extends Resource
## Tunable stats for an enemy archetype.

@export var enemy_id: StringName = &"scout"
@export var display_name: String = "Scout"
@export var max_hp: float = 2.0
@export var move_speed: float = 120.0
@export var score_value: int = 100
@export var fire_interval: float = 0.0
@export var projectile_speed: float = 220.0
@export var contact_damage: int = 1
@export var color: Color = Color(1.0, 0.45, 0.45)
@export var size: Vector2 = Vector2(28, 28)
@export var is_hazard: bool = false
@export var is_boss: bool = false
@export var scene_path: String = "res://scenes/entities/enemy_scout.tscn"
