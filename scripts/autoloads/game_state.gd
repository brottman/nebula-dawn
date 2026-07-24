extends Node
## Persistent campaign progress, run mode, session score, and mission stats.

const SAVE_PATH := "user://nebula_dawn.cfg"
## Sector 1 — five stages from Planetary Ascent through Flagship Core.
const SECTOR_1_PATHS := [
	"res://resources/missions/mission_01_planetary_ascent.tres",
	"res://resources/missions/mission_02_asteroid_belt.tres",
	"res://resources/missions/mission_03_nebula_anomaly.tres",
	"res://resources/missions/mission_04_cybernetic_hive.tres",
	"res://resources/missions/mission_05_flagship_core.tres",
]
const MISSION_PATHS := SECTOR_1_PATHS
const SECTOR_1 := 1

enum Mode { CAMPAIGN, ENDLESS }

var mode: Mode = Mode.CAMPAIGN
var current_mission_index: int = 0
var highest_unlocked_mission: int = 0
var last_score: int = 0
var last_won: bool = false
var endless_high_score: int = 0
var session_score: int = 0

## Per-run statistics shown on the mission results screen.
var run_active: bool = false
var run_elapsed: float = 0.0
var run_kills: int = 0
var run_hazards: int = 0
var run_pickups: int = 0
var run_hits_taken: int = 0
var run_formations: int = 0
var run_max_weapon_level: int = 1
var run_bosses_defeated: int = 0
## Letter rank from the last finished run ("" while in progress).
var last_rank: String = ""
var last_rank_bonus: int = 0


func _ready() -> void:
	load_progress()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.pickup_collected.connect(_on_pickup_collected)
	EventBus.formation_cleared.connect(_on_formation_cleared)
	EventBus.player_hull_hit.connect(_on_player_hull_hit)
	EventBus.weapon_changed.connect(_on_weapon_changed)


func _process(delta: float) -> void:
	if run_active:
		run_elapsed += delta


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	highest_unlocked_mission = int(cfg.get_value("campaign", "unlocked", 0))
	endless_high_score = int(cfg.get_value("endless", "high_score", 0))


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked", highest_unlocked_mission)
	cfg.set_value("endless", "high_score", endless_high_score)
	cfg.save(SAVE_PATH)


func start_campaign_mission(index: int) -> void:
	mode = Mode.CAMPAIGN
	current_mission_index = clampi(index, 0, MISSION_PATHS.size() - 1)
	session_score = 0
	last_score = 0
	last_won = false
	last_rank = ""
	last_rank_bonus = 0
	_reset_run_stats()


func start_endless() -> void:
	mode = Mode.ENDLESS
	current_mission_index = -1
	session_score = 0
	last_score = 0
	last_won = false
	last_rank = ""
	last_rank_bonus = 0
	_reset_run_stats()


func _reset_run_stats() -> void:
	run_active = true
	run_elapsed = 0.0
	run_kills = 0
	run_hazards = 0
	run_pickups = 0
	run_hits_taken = 0
	run_formations = 0
	run_max_weapon_level = 1
	run_bosses_defeated = 0


func get_power_floor(mission_index: int = -1) -> int:
	## Minimum weapon tier on respawn. Stages are 1-based in design docs;
	## mission_index is 0-based (0–4 = Sector 1 stages 1–5).
	var i := current_mission_index if mission_index < 0 else mission_index
	if mode == Mode.ENDLESS:
		# Endless ramps like late Sector 1.
		return 2 if run_elapsed > 90.0 else 1
	if i < 0:
		return 1
	if i <= 2:
		return 1 ## Stages 1–3
	if i <= 4:
		return 2 ## Stages 4–5
	# EX Stages 6–10 (future): Lv2 floor + utility on respawn.
	return 2


func is_ex_stage(mission_index: int = -1) -> bool:
	var i := current_mission_index if mission_index < 0 else mission_index
	return mode == Mode.CAMPAIGN and i >= 5


func get_mission_path(index: int = -1) -> String:
	var i := current_mission_index if index < 0 else index
	if i < 0 or i >= MISSION_PATHS.size():
		return ""
	return MISSION_PATHS[i]


func add_score(amount: int) -> void:
	session_score += amount
	EventBus.score_changed.emit(session_score)


func record_mission_result(won: bool) -> void:
	run_active = false
	last_won = won
	last_rank = ""
	last_rank_bonus = 0
	if won and mode == Mode.CAMPAIGN:
		var rank_info := compute_clear_rank()
		last_rank = String(rank_info.get("rank", "C"))
		last_rank_bonus = int(rank_info.get("bonus", 0))
		if last_rank_bonus > 0:
			session_score += last_rank_bonus
		var next := current_mission_index + 1
		if next > highest_unlocked_mission and next < MISSION_PATHS.size():
			highest_unlocked_mission = next
		elif current_mission_index == MISSION_PATHS.size() - 1:
			highest_unlocked_mission = maxi(highest_unlocked_mission, current_mission_index)
		save_progress()
	last_score = session_score
	if mode == Mode.ENDLESS:
		if session_score > endless_high_score:
			endless_high_score = session_score
			save_progress()


## Rank a campaign clear from hull hits, pace, aggression, and power ceiling.
## Returns { "rank": "S"|"A"|"B"|"C", "bonus": int, "points": int }.
func compute_clear_rank() -> Dictionary:
	var points := 0
	# Survival — the strongest lever; clean runs feel elite.
	if run_hits_taken <= 0:
		points += 45
	elif run_hits_taken <= 2:
		points += 32
	elif run_hits_taken <= 5:
		points += 18
	elif run_hits_taken <= 9:
		points += 8
	# Pace — stages are multi-minute; reward decisive clears without punishing careful play.
	if run_elapsed <= 150.0:
		points += 20
	elif run_elapsed <= 210.0:
		points += 12
	elif run_elapsed <= 270.0:
		points += 6
	# Aggression / mastery of stage toys.
	if current_mission_index == 0:
		if run_formations >= 4:
			points += 15
		elif run_formations >= 2:
			points += 8
	else:
		if run_kills >= 80:
			points += 12
		elif run_kills >= 50:
			points += 7
	# Power ceiling shows you rode the pickup economy.
	if run_max_weapon_level >= 3:
		points += 15
	elif run_max_weapon_level >= 2:
		points += 8
	if run_bosses_defeated >= 2:
		points += 5

	var rank := "C"
	var bonus := 500
	if points >= 85:
		rank = "S"
		bonus = 5000
	elif points >= 65:
		rank = "A"
		bonus = 2500
	elif points >= 40:
		rank = "B"
		bonus = 1200
	return {"rank": rank, "bonus": bonus, "points": points}


func has_next_mission() -> bool:
	return mode == Mode.CAMPAIGN and last_won and current_mission_index + 1 < MISSION_PATHS.size()


func next_mission_index() -> int:
	return current_mission_index + 1


func format_run_time() -> String:
	var t := int(run_elapsed)
	var m := t / 60
	var s := t % 60
	return "%02d:%02d" % [m, s]


func is_mission_unlocked(index: int) -> bool:
	return index <= highest_unlocked_mission


func get_mission_data(index: int = -1) -> MissionData:
	var path := get_mission_path(index)
	if path == "":
		return null
	return load(path) as MissionData


func sector_of(index: int = -1) -> int:
	var data := get_mission_data(index)
	return data.sector if data else SECTOR_1


func stage_of(index: int = -1) -> int:
	var data := get_mission_data(index)
	if data:
		return data.stage
	var i := current_mission_index if index < 0 else index
	return i + 1


func is_sector_finale(index: int = -1) -> bool:
	var i := current_mission_index if index < 0 else index
	return i == MISSION_PATHS.size() - 1


func stage_code(index: int = -1) -> String:
	return "%d-%d" % [sector_of(index), stage_of(index)]


func _on_enemy_killed(is_hazard: bool, is_boss: bool) -> void:
	if not run_active:
		return
	if is_hazard:
		run_hazards += 1
	else:
		run_kills += 1
	if is_boss:
		run_bosses_defeated += 1


func _on_pickup_collected(_kind: String) -> void:
	if run_active:
		run_pickups += 1


func _on_formation_cleared(_center: Vector2, _size: int) -> void:
	if run_active:
		run_formations += 1


func _on_player_hull_hit() -> void:
	if run_active:
		run_hits_taken += 1


func _on_weapon_changed(_weapon_name: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player == null:
		return
	var level = player.get("weapon_level")
	if level != null:
		run_max_weapon_level = maxi(run_max_weapon_level, int(level))
