extends Control
## Shared game world for campaign missions and Boss Rush.
## Playfield renders in a SubViewport below the top HUD bar so chrome
## does not cover the Camera2D action zone.

const HUD_TOP_HEIGHT := 72.0
const HUD_BOTTOM_HEIGHT := 84.0

@onready var playfield_host: SubViewportContainer = $PlayfieldHost
@onready var playfield: SubViewport = $PlayfieldHost/Playfield
@onready var parallax: Node2D = $PlayfieldHost/Playfield/ParallaxBg
@onready var player: CharacterBody2D = $PlayfieldHost/Playfield/Player
@onready var entities: Node2D = $PlayfieldHost/Playfield/Entities
@onready var projectiles: Node2D = $PlayfieldHost/Playfield/Projectiles
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var camera: Camera2D = $PlayfieldHost/Playfield/Camera2D
@onready var pool: ProjectilePool = $PlayfieldHost/Playfield/ProjectilePool
@onready var spawner: Node = $PlayfieldHost/Playfield/WaveSpawner
@onready var runner: Node = $PlayfieldHost/Playfield/MissionRunner
@onready var formation_tracker: Node = $PlayfieldHost/Playfield/FormationTracker
@onready var stage_director: Node = $PlayfieldHost/Playfield/StageDirector
@onready var intro_card: CanvasLayer = $StageIntro

var _shake_time: float = 0.0
var _shake_amount: float = 0.0
var _ending: bool = false
var _intro_active: bool = false


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
	runner.next_boss_requested.connect(_on_boss_rush_next)
	EventBus.screen_shake.connect(_on_shake)
	EventBus.hitstop_requested.connect(_on_hitstop)
	EventBus.pause_requested.connect(_on_pause_requested)
	if pause_menu.has_method("hide_menu"):
		pause_menu.hide_menu()
	get_viewport().size_changed.connect(_fit_playfield)
	_fit_playfield()
	AudioBus.play_game_music()
	_start_mode()


func _fit_playfield() -> void:
	var safe := _safe_area_insets()
	var top_chrome := HUD_TOP_HEIGHT + safe.y
	var bottom_chrome := HUD_BOTTOM_HEIGHT + safe.w
	playfield_host.offset_top = top_chrome
	playfield_host.offset_left = safe.x
	playfield_host.offset_right = -safe.z
	playfield_host.offset_bottom = -bottom_chrome
	# Container size updates after the current layout pass.
	call_deferred("_finish_fit_playfield")


func _finish_fit_playfield() -> void:
	var vp := Vector2(playfield.size)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	camera.position = vp * 0.5
	if _ending or not is_instance_valid(player) or player.dead:
		return
	var margin := 24.0
	player.global_position.x = clampf(player.global_position.x, margin, vp.x - margin)
	player.global_position.y = clampf(player.global_position.y, margin, vp.y - margin)
	# First fit: place near bottom-center if still at the editor default.
	if player.global_position.distance_to(Vector2(240, 540)) < 2.0 \
			or player.global_position.distance_to(Vector2(240, 600)) < 2.0:
		player.global_position = Vector2(vp.x * 0.5, vp.y * 0.83)


func _safe_area_insets() -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return Vector4.ZERO
	var vp := get_viewport().get_visible_rect().size
	var left := float(safe.position.x) / float(screen.x) * vp.x
	var top := float(safe.position.y) / float(screen.y) * vp.y
	var right := float(screen.x - safe.end.x) / float(screen.x) * vp.x
	var bottom := float(screen.y - safe.end.y) / float(screen.y) * vp.y
	return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))


func _start_mode() -> void:
	match GameState.mode:
		GameState.Mode.BOSS_RUSH:
			var rush_data := GameState.get_boss_rush_data()
			if rush_data == null:
				push_error("Missing boss rush data")
				return
			_apply_mission_ambience(rush_data)
			await _play_intro_card("BOSS RUSH", "RAID %d / %d" % [GameState.boss_rush_index + 1, GameState.boss_rush_count()],
				rush_data.boss.display_name if rush_data.boss else "Next target")
			stage_director.begin(rush_data)
			runner.begin_boss_rush(rush_data)
		_:
			var path := GameState.get_mission_path()
			var data: MissionData = load(path) if path != "" else null
			if data == null:
				push_error("Missing mission data: %s" % path)
				return
			_apply_mission_ambience(data)
			await _play_intro_card(GameState.stage_code(), data.title.to_upper(), data.subtitle)
			stage_director.begin(data)
			runner.begin_campaign(data)


func _apply_mission_ambience(data: MissionData) -> void:
	if parallax.has_method("set_tint"):
		parallax.set_tint(data.background_tint)
	parallax.scroll_speed = data.scroll_speed
	if parallax.has_method("set_terrain"):
		parallax.set_terrain(data.terrain_id)


## Freeze combat while the title card plays (card runs in PROCESS_MODE_ALWAYS),
## then hand control back to the mission runner.
func _play_intro_card(code: String, title: String, subtitle: String) -> void:
	if intro_card == null:
		return
	_intro_active = true
	get_tree().paused = true
	intro_card.visible = true
	await intro_card.play(code, title, subtitle)
	get_tree().paused = false
	_intro_active = false


## Boss Rush intermission: clean the field, repair the ship, swap arenas.
func _on_boss_rush_next(data: MissionData) -> void:
	if _ending:
		return
	if player and player.has_method("restore_full"):
		player.restore_full()
	if pool and pool.has_method("clear_enemy_in_radius"):
		var vp := Vector2(playfield.size)
		pool.clear_enemy_in_radius(vp * 0.5, maxf(vp.x, vp.y))
	_apply_mission_ambience(data)
	stage_director.begin(data)
	AudioBus.play_game_music()
	await _play_intro_card(
		"BOSS RUSH", "RAID %d / %d" % [GameState.boss_rush_index + 1, GameState.boss_rush_count()],
		data.boss.display_name if data.boss else "Next target")
	if _ending:
		return
	# Boss defeat arrives from a physics callback — defer the next spawn out of the flush.
	call_deferred("_continue_boss_rush", data)


func _continue_boss_rush(data: MissionData) -> void:
	if _ending or not is_inside_tree():
		return
	runner.continue_boss_rush(data)


func _on_hitstop(seconds: float) -> void:
	if _ending or seconds <= 0.0:
		return
	Engine.time_scale = 0.0
	await get_tree().create_timer(seconds, true, false, true).timeout
	if not is_inside_tree() or _ending:
		return
	var overdrive := false
	if player and is_instance_valid(player) and player.get("overdrive_time") != null:
		overdrive = float(player.overdrive_time) > 0.0
	Engine.time_scale = 0.4 if overdrive else 1.0


func _process(delta: float) -> void:
	# Only handles pause-to-open: once paused this node stops processing.
	# PauseMenu (PROCESS_ALWAYS) handles Esc to close / leave settings.
	if Input.is_action_just_pressed("pause") and not _ending and not _intro_active:
		if not get_tree().paused:
			_toggle_pause()
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		if _shake_time <= 0.0:
			camera.offset = Vector2.ZERO


func _on_pause_requested() -> void:
	if _ending or _intro_active:
		return
	if get_tree().paused:
		return
	_toggle_pause()


func _toggle_pause() -> void:
	var paused := get_tree().paused
	get_tree().paused = not paused
	if get_tree().paused:
		pause_menu.show_menu()
	else:
		pause_menu.hide_menu()


func _on_shake(amount: float, duration: float) -> void:
	var scaled := amount * GameState.shake_intensity
	if scaled <= 0.01:
		return
	_shake_amount = scaled
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
		var vp := Vector2(playfield.size)
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