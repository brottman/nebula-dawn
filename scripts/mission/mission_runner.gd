extends Node
## Owns win/lose for campaign, practice, or endless; drives WaveSpawner.
## Boss Rush runs all ten stage bosses back-to-back with no waves.

signal mission_complete(won: bool)
## Boss Rush: a target died and the next arena is ready to announce.
signal next_boss_requested(data: MissionData)

var mission: MissionData
var spawner: Node
var player: Node
var _boss_alive: bool = false
var _finished: bool = false
var _endless: bool = false
var _boss_rush: bool = false


func setup(wave_spawner: Node, player_node: Node) -> void:
	spawner = wave_spawner
	player = player_node
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)


## start_wave lets practice skip ahead (0 = first wave, waves.size() = boss).
func begin_campaign(data: MissionData, start_wave: int = 0) -> void:
	mission = data
	_endless = false
	_boss_rush = false
	_finished = false
	_boss_alive = false
	if spawner.has_signal("all_waves_cleared") and not spawner.all_waves_cleared.is_connected(_on_waves_cleared):
		spawner.all_waves_cleared.connect(_on_waves_cleared)
	if spawner.has_signal("boss_requested") and not spawner.boss_requested.is_connected(_on_boss_requested):
		spawner.boss_requested.connect(_on_boss_requested)
	spawner.start_mission(data, start_wave)


func begin_endless() -> void:
	mission = null
	_endless = true
	_boss_rush = false
	_finished = false
	spawner.start_endless()


## Boss Rush: drop straight into the stage boss, no waves.
func begin_boss_rush(data: MissionData) -> void:
	mission = data
	_endless = false
	_boss_rush = true
	_finished = false
	_boss_alive = false
	await get_tree().create_timer(0.5).timeout
	if _finished or mission != data:
		return
	_boss_alive = true
	spawner.spawn_boss(data.boss)


func continue_boss_rush(data: MissionData) -> void:
	if _finished:
		return
	mission = data
	_boss_alive = true
	spawner.spawn_boss(data.boss)


func _on_waves_cleared() -> void:
	if _finished or _endless:
		return
	if mission and mission.boss:
		return
	_finish(true)


func _on_boss_requested() -> void:
	if mission == null or mission.boss == null:
		_finish(true)
		return
	_boss_alive = true
	await get_tree().create_timer(mission.boss_intro_delay).timeout
	if _finished:
		return
	spawner.spawn_boss(mission.boss)


func _on_boss_defeated() -> void:
	if _finished:
		return
	# Mid-bosses also emit boss_defeated for HUD cleanup; only the stage boss ends the run.
	if not _boss_alive:
		return
	_boss_alive = false
	if _boss_rush:
		_advance_boss_rush()
		return
	_finish(true)


func _advance_boss_rush() -> void:
	GameState.boss_rush_index += 1
	if GameState.boss_rush_index >= GameState.boss_rush_count():
		_boss_rush = false
		_finish(true)
		return
	var data := GameState.get_boss_rush_data()
	if data == null:
		_boss_rush = false
		_finish(true)
		return
	GameState.current_mission_index = GameState.boss_rush_index
	mission = data
	next_boss_requested.emit(data)


func _on_player_died() -> void:
	if _finished:
		return
	_finish(false)


func _finish(won: bool) -> void:
	_finished = true
	GameState.record_mission_result(won)
	if won:
		EventBus.mission_won.emit()
	else:
		EventBus.mission_lost.emit()
	mission_complete.emit(won)
