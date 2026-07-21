extends Node
## Persistent campaign progress, run mode, and session score.

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


func _ready() -> void:
	load_progress()


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


func start_endless() -> void:
	mode = Mode.ENDLESS
	current_mission_index = -1
	session_score = 0
	last_score = 0
	last_won = false


func get_mission_path(index: int = -1) -> String:
	var i := current_mission_index if index < 0 else index
	if i < 0 or i >= MISSION_PATHS.size():
		return ""
	return MISSION_PATHS[i]


func add_score(amount: int) -> void:
	session_score += amount
	EventBus.score_changed.emit(session_score)


func record_mission_result(won: bool) -> void:
	last_won = won
	last_score = session_score
	if won and mode == Mode.CAMPAIGN:
		var next := current_mission_index + 1
		if next > highest_unlocked_mission and next < MISSION_PATHS.size():
			highest_unlocked_mission = next
		elif current_mission_index == MISSION_PATHS.size() - 1:
			highest_unlocked_mission = maxi(highest_unlocked_mission, current_mission_index)
		save_progress()
	if mode == Mode.ENDLESS:
		if session_score > endless_high_score:
			endless_high_score = session_score
			save_progress()


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
