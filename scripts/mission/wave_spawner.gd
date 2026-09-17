extends Node
## Spawns waves from MissionData.
## Campaign waves use hybrid clear: advance when the wave is destroyed OR max_clear_time expires.

signal wave_started(index: int, total: int)
signal all_waves_cleared
signal boss_requested
signal enemy_spawned(enemy_id: String)

var mission: MissionData
var projectile_pool: ProjectilePool
var enemy_container: Node2D
var scroll_speed: float = 40.0

var _wave_index: int = -1
var _spawning: bool = false
var _waiting_clear: bool = false
var _active_enemies: int = 0
var _wave_enemies_alive: int = 0
var _clear_timer: float = 0.0
var _max_clear_time: float = 0.0
var _recovery_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

## Performance-aware pacing. The authored mission remains the baseline; these
## values only open a little breathing room when the player is under pressure.
const INTENSITY_MIN_ENTRY_SCALE := 1.18
const INTENSITY_MAX_ENTRY_SCALE := 0.82
const INTENSITY_MIN_START_SCALE := 1.12
const INTENSITY_MAX_START_SCALE := 0.84
const MAX_EXPECTED_ACTIVE_ENEMIES := 24.0
const INTENSITY_SMOOTHING := 0.7
const HIT_RELIEF_DURATION := 2.5
const DEATH_RELIEF_DURATION := 5.0

var _intensity: float = 0.25
var _intensity_target: float = 0.25
var _recent_hit_timer: float = 0.0
var _recent_death_timer: float = 0.0
var _player_hp_ratio: float = 1.0
var _player_lives: int = 3
var _player_weapon_level: int = 1


func setup(pool: ProjectilePool, container: Node2D) -> void:
	projectile_pool = pool
	enemy_container = container
	_rng.randomize()
	if not EventBus.player_hp_changed.is_connected(_on_player_hp_changed):
		EventBus.player_hp_changed.connect(_on_player_hp_changed)
	if not EventBus.player_hull_hit.is_connected(_on_player_hull_hit):
		EventBus.player_hull_hit.connect(_on_player_hull_hit)
	if not EventBus.player_lives_changed.is_connected(_on_player_lives_changed):
		EventBus.player_lives_changed.connect(_on_player_lives_changed)


func start_mission(data: MissionData) -> void:
	mission = data
	_wave_index = -1
	_spawning = false
	_waiting_clear = false
	_active_enemies = 0
	_wave_enemies_alive = 0
	_clear_timer = 0.0
	_max_clear_time = 0.0
	_recovery_timer = 0.0
	_intensity = 0.25
	_intensity_target = 0.25
	_recent_hit_timer = 0.0
	_recent_death_timer = 0.0
	scroll_speed = data.scroll_speed if data else 40.0
	_update_intensity(0.0)
	_next_wave()


func _process(delta: float) -> void:
	_update_intensity(delta)
	if _recovery_timer > 0.0:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			_next_wave()
		return
	if not _waiting_clear or _spawning:
		return
	# Hybrid: clear this wave's enemies OR hit the max timer.
	if _wave_enemies_alive <= 0:
		_advance_from_wave(true)
		return
	if _max_clear_time > 0.0:
		_clear_timer += delta
		if _clear_timer >= _max_clear_time:
			_advance_from_wave(false)


func _advance_from_wave(full_clear: bool = false) -> void:
	if not _waiting_clear:
		return
	_waiting_clear = false
	_clear_timer = 0.0
	_max_clear_time = 0.0
	# Stop attributing leftovers to this wave so they can't stall the next one.
	_wave_enemies_alive = 0
	EventBus.wave_cleared.emit(_wave_index)
	if full_clear:
		_try_rare_wave_reward()
	var wave: WaveDef = mission.waves[_wave_index] if mission and _wave_index < mission.waves.size() else null
	if wave and wave.recovery_delay > 0.0:
		var recovery_scale := lerpf(1.25, 0.80, _intensity)
		_recovery_timer = wave.recovery_delay * recovery_scale
	else:
		_next_wave()


func _try_rare_wave_reward() -> void:
	## Full wipe (not a timeout) — sparse defensive / utility drop.
	if _rng.randf() > 0.25:
		return
	if enemy_container == null:
		return
	var rares := ["shield", "bomb", "energy"]
	var kind: String = rares[_rng.randi() % rares.size()]
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var p: Node = scene.instantiate()
	enemy_container.add_child(p)
	var vp := get_viewport().get_visible_rect().size
	p.global_position = Vector2(vp.x * 0.5, vp.y * 0.28)
	if p.has_method("setup"):
		p.setup(kind)
	EventBus.gimmick_toast.emit("WAVE BONUS")


func _next_wave() -> void:
	if mission == null:
		return
	_wave_index += 1
	if _wave_index >= mission.waves.size():
		if mission.boss:
			boss_requested.emit()
		else:
			all_waves_cleared.emit()
		return
	var wave: WaveDef = mission.waves[_wave_index]
	var label := wave.label if wave.label != "" else "Wave"
	EventBus.wave_started.emit(_wave_index, mission.waves.size(), label)
	wave_started.emit(_wave_index, mission.waves.size())
	_spawning = true
	_wave_enemies_alive = 0
	_run_wave(wave)


func _run_wave(wave: WaveDef) -> void:
	await get_tree().create_timer(_effective_start_delay(wave.start_delay)).timeout
	for entry in wave.entries:
		if entry == null or entry.enemy == null:
			continue
		await get_tree().create_timer(_effective_entry_delay(entry.delay)).timeout
		var offs := entry.offsets()
		# One seed per entry: every member derives identical motion params so the
		# formation stays coherent and flies as a single unit.
		var pass_seed := _rng.randf() * TAU
		var slot_extent := 0.0
		for off in offs:
			slot_extent = maxf(slot_extent, absf(off.x))
		_spawn_entry_telegraph(entry, offs)
		for off in offs:
			_spawn_enemy(entry.enemy, entry.position + off, true, entry.formation_id, entry.flight_pattern, off, pass_seed, slot_extent)
	_spawning = false
	if wave.clear_required:
		_waiting_clear = true
		_clear_timer = 0.0
		_max_clear_time = wave.max_clear_time
		# If nothing survived spawn (edge case), advance immediately next frame.
	else:
		await get_tree().create_timer(0.5).timeout
		_next_wave()


func _effective_entry_delay(authored_delay: float) -> float:
	var scale := lerpf(INTENSITY_MIN_ENTRY_SCALE, INTENSITY_MAX_ENTRY_SCALE, _intensity)
	return maxf(0.0, authored_delay * scale)


func _effective_start_delay(authored_delay: float) -> float:
	var scale := lerpf(INTENSITY_MIN_START_SCALE, INTENSITY_MAX_START_SCALE, _intensity)
	return maxf(0.0, authored_delay * scale)


func _update_intensity(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var hp_value: Variant = player.get("hp")
		var max_hp_value: Variant = player.get("max_hp")
		if hp_value != null and max_hp_value != null:
			_player_hp_ratio = clampf(float(hp_value) / maxf(float(max_hp_value), 1.0), 0.0, 1.0)
		var lives_value: Variant = player.get("lives")
		if lives_value != null:
			_player_lives = maxi(0, int(lives_value))
		var weapon_level_value: Variant = player.get("weapon_level")
		if weapon_level_value != null:
			_player_weapon_level = clampi(int(weapon_level_value), 1, 5)
	_recent_hit_timer = maxf(0.0, _recent_hit_timer - delta)
	_recent_death_timer = maxf(0.0, _recent_death_timer - delta)

	var progress := 0.0
	if mission and mission.waves.size() > 1:
		progress = clampf(float(maxi(_wave_index, 0)) / float(mission.waves.size() - 1), 0.0, 1.0)
	var stage_pressure := 0.18 + progress * 0.58
	var weapon_pressure := float(_player_weapon_level - 1) / 4.0 * 0.12
	var health_pressure := _player_hp_ratio * 0.08
	var enemy_pressure := clampf(float(_active_enemies) / MAX_EXPECTED_ACTIVE_ENEMIES, 0.0, 1.0) * 0.12
	var hit_relief := clampf(_recent_hit_timer / HIT_RELIEF_DURATION, 0.0, 1.0) * 0.18
	var death_relief := clampf(_recent_death_timer / DEATH_RELIEF_DURATION, 0.0, 1.0) * 0.38
	var health_relief := (1.0 - _player_hp_ratio) * 0.30
	_intensity_target = clampf(
		stage_pressure + weapon_pressure + health_pressure + enemy_pressure \
			- hit_relief - death_relief - health_relief,
		0.08,
		1.0
	)
	_intensity = move_toward(_intensity, _intensity_target, delta * INTENSITY_SMOOTHING)
	if projectile_pool and projectile_pool.has_method("set_enemy_projectile_pressure"):
		projectile_pool.set_enemy_projectile_pressure(_intensity)


func _on_player_hp_changed(current: int, maximum: int) -> void:
	_player_hp_ratio = clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)


func _on_player_hull_hit() -> void:
	_recent_hit_timer = HIT_RELIEF_DURATION


func _on_player_lives_changed(lives: int) -> void:
	if lives < _player_lives:
		_recent_death_timer = DEATH_RELIEF_DURATION
	_player_lives = lives


func _spawn_entry_telegraph(entry: SpawnEntry, offs: Array[Vector2]) -> void:
	if enemy_container == null or entry == null or entry.enemy == null or offs.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var positions: Array[Vector2] = []
	var flight := String(entry.flight_pattern)
	if flight == "":
		flight = String(entry.enemy.flight_pattern)
	var side_entry := flight in ["loop", "sweep", "arc"]
	if side_entry:
		# Side-entry formations are authored off-screen; show one marker at the
		# matching edge so the player can anticipate the pass without clutter.
		var from_left := entry.position.x <= vp.x * 0.5
		var edge_x := 24.0 if from_left else vp.x - 24.0
		positions.append(Vector2(edge_x, clampf(vp.y * 0.45, 54.0, vp.y - 54.0)))
	else:
		# Top-entry formations reveal their horizontal footprint at the playfield
		# edge. Clamp wide formations so their markers remain readable on-screen.
		var anchor_x := clampf(entry.position.x, 22.0, vp.x - 22.0)
		for off in offs:
			positions.append(Vector2(
				clampf(anchor_x + off.x, 18.0, vp.x - 18.0),
				26.0 + clampf(off.y * 0.12, -8.0, 14.0)
			))
	var tint := entry.enemy.color.lightened(0.22)
	CombatFX.spawn_entry_telegraph(enemy_container, positions, Color(tint.r, tint.g, tint.b, 1.0))


func _spawn_enemy(stats: EnemyStats, pos: Vector2, count_for_wave: bool = false, formation_id: String = "", flight_override: StringName = &"", slot: Vector2 = Vector2.ZERO, pass_seed: float = 0.0, slot_extent: float = 0.0) -> void:
	var path := stats.scene_path if stats.scene_path != "" else "res://scenes/entities/enemy_base.tscn"
	var scene: PackedScene = load(path)
	if scene == null:
		scene = load("res://scenes/entities/enemy_base.tscn")
	var enemy: Node = scene.instantiate()
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	if enemy.has_method("setup"):
		enemy.setup(stats, projectile_pool, scroll_speed, formation_id, flight_override, slot, pass_seed, slot_extent)
	if enemy.has_method("_side_spawn_setup"):
		enemy._side_spawn_setup()
	_active_enemies += 1
	enemy_spawned.emit(String(stats.enemy_id))
	if count_for_wave:
		_wave_enemies_alive += 1
		enemy.tree_exited.connect(_on_wave_enemy_exited)
	else:
		enemy.tree_exited.connect(_on_enemy_exited)


func _on_enemy_exited() -> void:
	_active_enemies = maxi(0, _active_enemies - 1)


func _on_wave_enemy_exited() -> void:
	_active_enemies = maxi(0, _active_enemies - 1)
	_wave_enemies_alive = maxi(0, _wave_enemies_alive - 1)


func spawn_boss(stats: EnemyStats) -> void:
	var vp := get_viewport().get_visible_rect().size
	_spawn_enemy(stats, Vector2(vp.x * 0.5, -60.0), false, "")


func get_active_enemy_count() -> int:
	return _active_enemies
