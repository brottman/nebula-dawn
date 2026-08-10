extends Node
## Spawns waves from MissionData or endless difficulty ramp.
## Campaign waves use hybrid clear: advance when the wave is destroyed OR max_clear_time expires.

signal wave_started(index: int, total: int)
signal all_waves_cleared
signal boss_requested

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
var _endless: bool = false
var _endless_time: float = 0.0
var _endless_spawn_cd: float = 2.0
var _endless_next: float = 1.0
var _rng := RandomNumberGenerator.new()

var _enemy_catalog: Array[EnemyStats] = []


func setup(pool: ProjectilePool, container: Node2D) -> void:
	projectile_pool = pool
	enemy_container = container
	_rng.randomize()
	_load_catalog()


func _load_catalog() -> void:
	_enemy_catalog.clear()
	for path in [
		"res://resources/enemies/scout.tres",
		"res://resources/enemies/strafer.tres",
		"res://resources/enemies/drone.tres",
		"res://resources/enemies/asteroid.tres",
	]:
		var s: EnemyStats = load(path)
		if s:
			_enemy_catalog.append(s)


## start_wave is 0-based (0 = first wave; waves.size() = start at the boss).
func start_mission(data: MissionData, start_wave: int = 0) -> void:
	mission = data
	_endless = false
	_wave_index = -1
	_spawning = false
	_waiting_clear = false
	_active_enemies = 0
	_wave_enemies_alive = 0
	_clear_timer = 0.0
	_max_clear_time = 0.0
	scroll_speed = data.scroll_speed if data else 40.0
	_wave_index = clampi(start_wave, 0, data.waves.size() if data else 0) - 1
	_next_wave()


func start_endless() -> void:
	mission = null
	_endless = true
	_endless_time = 0.0
	_endless_spawn_cd = 2.2
	_endless_next = 1.0
	_active_enemies = 0
	_wave_enemies_alive = 0
	_waiting_clear = false
	scroll_speed = 50.0


func _process(delta: float) -> void:
	if _endless:
		_process_endless(delta)
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
	_next_wave()


func _try_rare_wave_reward() -> void:
	## Full wipe (not a timeout) — sparse defensive / utility drop.
	if _rng.randf() > 0.40:
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


func _process_endless(delta: float) -> void:
	_endless_time += delta
	_endless_next -= delta
	var difficulty := 1.0 + _endless_time / 45.0
	scroll_speed = 50.0 + difficulty * 8.0
	_endless_spawn_cd = maxf(0.55, 2.2 - difficulty * 0.25)
	if _endless_next <= 0.0:
		_endless_next = _endless_spawn_cd
		_spawn_endless_group(difficulty)


func _spawn_endless_group(difficulty: float) -> void:
	if _enemy_catalog.is_empty():
		return
	var count := mini(3 + int(difficulty * 0.6), 7)
	var vp_w := get_viewport().get_visible_rect().size.x
	var stats: EnemyStats = _enemy_catalog[_rng.randi() % _enemy_catalog.size()]
	if difficulty > 2.0 and _rng.randf() < 0.45:
		for s in _enemy_catalog:
			if s.enemy_id == &"strafer" or s.enemy_id == &"drone":
				stats = s
				break
	var patterns: Array[StringName] = [&"v", &"arc", &"wave", &"line", &"diamond", &"column"]
	var pat: StringName = patterns[_rng.randi() % patterns.size()]
	var origin := Vector2(_rng.randf_range(90.0, vp_w - 90.0), -50.0)
	var spread := 48.0 + difficulty * 2.0
	var offs := SpawnEntry.pattern_offsets(pat, count, spread, Vector2(spread, 0))
	for off in offs:
		_spawn_enemy(stats, origin + off, false, "")


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
	await get_tree().create_timer(wave.start_delay).timeout
	for entry in wave.entries:
		if entry == null or entry.enemy == null:
			continue
		await get_tree().create_timer(entry.delay).timeout
		var offs := entry.offsets()
		for off in offs:
			_spawn_enemy(entry.enemy, entry.position + off, true, entry.formation_id)
	_spawning = false
	if wave.clear_required:
		_waiting_clear = true
		_clear_timer = 0.0
		_max_clear_time = wave.max_clear_time
		# If nothing survived spawn (edge case), advance immediately next frame.
	else:
		await get_tree().create_timer(0.5).timeout
		_next_wave()


func _spawn_enemy(stats: EnemyStats, pos: Vector2, count_for_wave: bool = false, formation_id: String = "") -> void:
	var path := stats.scene_path if stats.scene_path != "" else "res://scenes/entities/enemy_base.tscn"
	var scene: PackedScene = load(path)
	if scene == null:
		scene = load("res://scenes/entities/enemy_base.tscn")
	var enemy: Node = scene.instantiate()
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	if enemy.has_method("setup"):
		enemy.setup(stats, projectile_pool, scroll_speed, formation_id)
	_active_enemies += 1
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
