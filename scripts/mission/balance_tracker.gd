class_name BalanceTracker
extends Node
## Runtime telemetry for tuning missions without changing gameplay behavior.

const WEAPON_NAMES := {
	0: "BLASTER",
	1: "SPREAD",
	2: "LASER",
	3: "HOMING",
}

var spawner: Node
var projectile_pool: Node
var runner: Node
var player: Node

var _elapsed := 0.0
var _enemies_spawned := 0
var _peak_active_enemies := 0
var _peak_enemy_bullets := 0
var _current_weapon := "BLASTER"
var _weapon_seconds: Dictionary = {}
var _wave_started_at: Dictionary = {}
var _wave_durations: Array[Dictionary] = []
var _last_report: Dictionary = {}


func setup(p_spawner: Node, p_pool: Node, p_runner: Node, p_player: Node) -> void:
	spawner = p_spawner
	projectile_pool = p_pool
	runner = p_runner
	player = p_player
	for weapon_name in WEAPON_NAMES.values():
		_weapon_seconds[String(weapon_name)] = 0.0
	if spawner and spawner.has_signal("enemy_spawned"):
		spawner.enemy_spawned.connect(_on_enemy_spawned)
	if not EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.connect(_on_wave_started)
	if not EventBus.wave_cleared.is_connected(_on_wave_cleared):
		EventBus.wave_cleared.connect(_on_wave_cleared)
	if runner and runner.has_signal("mission_complete") \
			and not runner.mission_complete.is_connected(_on_mission_complete):
		runner.mission_complete.connect(_on_mission_complete)


func _process(delta: float) -> void:
	if _last_report.size() > 0:
		return
	_elapsed += delta
	var active_enemies: int = spawner.get_active_enemy_count() if spawner \
			and spawner.has_method("get_active_enemy_count") else 0
	var active_bullets: int = projectile_pool.get_active_enemy_projectiles().size() \
			if projectile_pool and projectile_pool.has_method("get_active_enemy_projectiles") else 0
	_peak_active_enemies = maxi(_peak_active_enemies, active_enemies)
	_peak_enemy_bullets = maxi(_peak_enemy_bullets, active_bullets)
	var weapon_id := int(player.get("weapon")) if player else 0
	_current_weapon = String(WEAPON_NAMES.get(weapon_id, "BLASTER"))
	_weapon_seconds[_current_weapon] = float(_weapon_seconds.get(_current_weapon, 0.0)) + delta


func _on_enemy_spawned(_enemy_id: String) -> void:
	_enemies_spawned += 1


func _on_wave_started(wave_index: int, _total_waves: int, _label: String) -> void:
	_wave_started_at[wave_index] = _elapsed


func _on_wave_cleared(wave_index: int) -> void:
	if not _wave_started_at.has(wave_index):
		return
	_wave_durations.append({
		"wave": wave_index + 1,
		"duration": snappedf(_elapsed - float(_wave_started_at[wave_index]), 0.01),
	})


func _on_mission_complete(won: bool) -> void:
	_last_report = _build_report(won)


func _build_report(won: bool) -> Dictionary:
	var total_weapon_time := 0.0
	for value in _weapon_seconds.values():
		total_weapon_time += float(value)
	var weapon_usage: Dictionary = {}
	for weapon_name in _weapon_seconds:
		var seconds := float(_weapon_seconds[weapon_name])
		weapon_usage[weapon_name] = {
			"seconds": snappedf(seconds, 0.01),
			"share": snappedf(seconds / maxf(total_weapon_time, 0.01), 0.001),
		}
	var average_wave_duration := 0.0
	if not _wave_durations.is_empty():
		for wave in _wave_durations:
			average_wave_duration += float(wave.get("duration", 0.0))
		average_wave_duration /= float(_wave_durations.size())
	return {
		"mission_index": GameState.current_mission_index,
		"mission_code": GameState.stage_code(),
		"won": won,
		"elapsed_seconds": snappedf(_elapsed, 0.01),
		"enemies_spawned": _enemies_spawned,
		"peak_simultaneous_enemies": _peak_active_enemies,
		"peak_enemy_bullets": _peak_enemy_bullets,
		"average_wave_duration": snappedf(average_wave_duration, 0.01),
		"waves_cleared": _wave_durations.size(),
		"wave_durations": _wave_durations,
		"player_hits": GameState.run_hits_taken,
		"weapon_usage": weapon_usage,
	}


func get_report() -> Dictionary:
	if _last_report.size() > 0:
		return _last_report.duplicate(true)
	return _build_report(false)


func has_finished() -> bool:
	return _last_report.size() > 0


func write_report(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write balance report: %s" % path)
		return false
	file.store_string(JSON.stringify(get_report(), "\t") + "\n")
	file.close()
	return true
