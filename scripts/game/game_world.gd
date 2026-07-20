extends Node2D
## Shared game world for campaign missions and endless mode.

@onready var parallax: Node2D = $ParallaxBg
@onready var player: CharacterBody2D = $Player
@onready var entities: Node2D = $Entities
@onready var projectiles: Node2D = $Projectiles
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var camera: Camera2D = $Camera2D
@onready var pool: ProjectilePool = $ProjectilePool
@onready var spawner: Node = $WaveSpawner
@onready var runner: Node = $MissionRunner

var _shake_time: float = 0.0
var _shake_amount: float = 0.0
var _ending: bool = false


func _ready() -> void:
	pool.player_projectile_scene = load("res://scenes/entities/projectile.tscn")
	pool.enemy_projectile_scene = load("res://scenes/entities/projectile.tscn")
	pool.setup(projectiles)
	player.setup(pool)
	spawner.setup(pool, entities)
	runner.setup(spawner, player)
	runner.mission_complete.connect(_on_mission_complete)
	EventBus.screen_shake.connect(_on_shake)
	if pause_menu.has_method("hide_menu"):
		pause_menu.hide_menu()
	_start_mode()


func _start_mode() -> void:
	match GameState.mode:
		GameState.Mode.ENDLESS:
			if parallax.has_method("set_tint"):
				parallax.set_tint(Color(0.25, 0.08, 0.2))
			if parallax.get("scroll_speed") != null:
				parallax.scroll_speed = 50.0
			runner.begin_endless()
		_:
			var path := GameState.get_mission_path()
			var data: MissionData = load(path) if path != "" else null
			if data == null:
				push_error("Missing mission data: %s" % path)
				return
			if parallax.has_method("set_tint"):
				parallax.set_tint(data.background_tint)
			parallax.scroll_speed = data.scroll_speed
			runner.begin_campaign(data)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _ending:
		_toggle_pause()
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		if _shake_time <= 0.0:
			camera.offset = Vector2.ZERO
	if GameState.mode == GameState.Mode.ENDLESS:
		parallax.scroll_speed = spawner.scroll_speed


func _toggle_pause() -> void:
	var paused := get_tree().paused
	get_tree().paused = not paused
	if get_tree().paused:
		pause_menu.show_menu()
	else:
		pause_menu.hide_menu()


func _on_shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_time = duration


func _on_mission_complete(won: bool) -> void:
	if _ending:
		return
	_ending = true
	await get_tree().create_timer(1.2).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/mission_results.tscn")
