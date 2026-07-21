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
@onready var formation_tracker: Node = $FormationTracker
@onready var stage_director: Node = $StageDirector

var _shake_time: float = 0.0
var _shake_amount: float = 0.0
var _ending: bool = false


func _ready() -> void:
	pool.player_projectile_scene = load("res://scenes/entities/projectile.tscn")
	pool.enemy_projectile_scene = load("res://scenes/entities/projectile.tscn")
	pool.setup(projectiles)
	player.setup(pool)
	formation_tracker.setup(pool)
	stage_director.setup(player, pool, entities, formation_tracker)
	spawner.setup(pool, entities)
	runner.setup(spawner, player)
	runner.mission_complete.connect(_on_mission_complete)
	EventBus.screen_shake.connect(_on_shake)
	if pause_menu.has_method("hide_menu"):
		pause_menu.hide_menu()
	get_viewport().size_changed.connect(_fit_playfield)
	_fit_playfield()
	AudioBus.play_game_music()
	_start_mode()


func _fit_playfield() -> void:
	var vp := get_viewport_rect().size
	camera.position = vp * 0.5
	if _ending or not is_instance_valid(player) or player.dead:
		return
	var margin := 24.0
	player.global_position.x = clampf(player.global_position.x, margin, vp.x - margin)
	player.global_position.y = clampf(player.global_position.y, margin, vp.y - margin)
	# First fit: place near bottom-center if still at the editor default.
	if player.global_position.distance_to(Vector2(240, 600)) < 2.0:
		player.global_position = Vector2(vp.x * 0.5, vp.y * 0.83)


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
			stage_director.begin(data)
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	if player and player.has_method("clear_zone_effects"):
		player.clear_zone_effects()
	# Freeze remaining threats so the outro reads cleanly.
	_freeze_combat()
	if won and is_instance_valid(player) and not player.dead and player.has_method("play_victory_exit"):
		if hud:
			hud.visible = false
		await player.play_victory_exit()
		await get_tree().create_timer(0.25).timeout
	else:
		await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/ui/mission_results.tscn")


func _freeze_combat() -> void:
	if pool and pool.has_method("clear_enemy_in_radius"):
		var vp := get_viewport_rect().size
		pool.clear_enemy_in_radius(vp * 0.5, maxf(vp.x, vp.y))
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == player:
			continue
		if n.has_method("set_physics_process"):
			n.set_physics_process(false)
		if n.has_method("set_process"):
			n.set_process(false)
	for n in get_tree().get_nodes_in_group("hazards"):
		if n.has_method("set_physics_process"):
			n.set_physics_process(false)
	if stage_director and stage_director.has_method("stop"):
		stage_director.stop()
	if spawner and spawner.has_method("set_process"):
		spawner.set_process(false)
