class_name MissionData
extends Resource
## Campaign mission definition loaded by MissionRunner.

@export var mission_id: StringName = &"mission_01"
@export var title: String = "Dawn Patrol"
@export var subtitle: String = "Clear the outer patrol routes."
@export var scroll_speed: float = 40.0
@export var waves: Array[WaveDef] = []
@export var win_on_waves_cleared: bool = true
@export var boss: EnemyStats
@export var boss_intro_delay: float = 1.5
@export var background_tint: Color = Color(0.15, 0.2, 0.45)
