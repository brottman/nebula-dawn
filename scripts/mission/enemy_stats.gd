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
## Fodder fire style: straight | aimed | side | burst | spread
@export var fire_pattern: StringName = &"straight"
@export var color: Color = Color(1.0, 0.45, 0.45)
@export var size: Vector2 = Vector2(28, 28)
@export var is_hazard: bool = false
@export var is_boss: bool = false
## Mid-boss: uses boss HUD/pattern but does not end the mission when defeated.
@export var is_mid_boss: bool = false
## Boss attack routine key. Stage bosses: orbital, megalith, leviathan,
## fabrication, omega, kaleidoscope, tempest, choir, junkyard, dawn.
## Mid-bosses: transport, drill, stalker, overseer, ace, prism,
## coil, echo, tyrant, herald. Drives BossPatterns.
## New bosses = a new archetype + a pattern branch in scripts/enemies/boss_patterns.gd,
## never string-matching display_name.
@export var boss_archetype: StringName = &""
@export var scene_path: String = "res://scenes/entities/enemy_base.tscn"