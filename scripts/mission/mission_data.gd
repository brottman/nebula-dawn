class_name MissionData
extends Resource
## Campaign mission definition loaded by MissionRunner.

@export var mission_id: StringName = &"mission_01"
@export var title: String = "Planetary Ascent"
@export var subtitle: String = "Break low orbit."
## Campaign sector this stage belongs to (1 = opening sector).
@export var sector: int = 1
## Stage number within the sector (1–5 for Sector 1).
@export var stage: int = 1
@export var scroll_speed: float = 40.0
@export var waves: Array[WaveDef] = []
@export var win_on_waves_cleared: bool = true
@export var boss: EnemyStats
@export var boss_intro_delay: float = 1.5
@export var background_tint: Color = Color(0.15, 0.2, 0.45)
## Stage gimmick module id: formations | asteroids | nebula | hive | gravity
@export var gimmick_id: StringName = &""
