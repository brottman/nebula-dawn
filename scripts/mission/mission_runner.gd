extends Node
## Owns win/lose for campaign or endless; drives WaveSpawner.

signal mission_complete(won: bool)

var mission: MissionData
var spawner: Node
var player: Node
var _boss_alive: bool = false
var _finished: bool = false
var _endless: bool = false


func setup(wave_spawner: Node, player_node: Node) -> void:
	spawner = wave_spawner
	player = player_node
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)


func begin_campaign(data: MissionData) -> void:
	mission = data
	_endless = false
	_finished = false
	_boss_alive = false
	if spawner.has_signal("all_waves_cleared") and not spawner.all_waves_cleared.is_connected(_on_waves_cleared):
		spawner.all_waves_cleared.connect(_on_waves_cleared)
	if spawner.has_signal("boss_requested") and not spawner.boss_requested.is_connected(_on_boss_requested):
		spawner.boss_requested.connect(_on_boss_requested)
	spawner.start_mission(data)


func begin_endless() -> void:
	mission = null
	_endless = true
	_finished = false
	spawner.start_endless()


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
	_boss_alive = false
	_finish(true)


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
