extends Node
## Persistent campaign progress, hangar, settings, run mode, and mission stats.

const SAVE_PATH := "user://nebula_dawn.cfg"
const Ships := preload("res://scripts/hangar/ship_catalog.gd")
## Sector 1 — five stages from Planetary Ascent through Flagship Core.
const SECTOR_1_PATHS := [
	"res://resources/missions/mission_01_planetary_ascent.tres",
	"res://resources/missions/mission_02_asteroid_belt.tres",
	"res://resources/missions/mission_03_nebula_anomaly.tres",
	"res://resources/missions/mission_04_cybernetic_hive.tres",
	"res://resources/missions/mission_05_flagship_core.tres",
]
## Sector 2 — five stages beyond the Flagship Core.
const SECTOR_2_PATHS := [
	"res://resources/missions/mission_06_mirror_field.tres",
	"res://resources/missions/mission_07_ion_storm.tres",
	"res://resources/missions/mission_08_phantom_wake.tres",
	"res://resources/missions/mission_09_scrap_gauntlet.tres",
	"res://resources/missions/mission_10_dawn_gate.tres",
]
const MISSION_PATHS := SECTOR_1_PATHS + SECTOR_2_PATHS
const SECTOR_1 := 1
const SECTOR_2 := 2
const SECTOR_1_COUNT := 5
const RANK_ORDER := {"S": 4, "A": 3, "B": 2, "C": 1}

enum Mode { CAMPAIGN, BOSS_RUSH }

## Combo chain: every kill/graze extends the window; a bigger chain pays more.
const COMBO_WINDOW := 2.5
const COMBO_BONUS_PER_KILL := 20
const GRAZE_SCORE := 30

var mode: Mode = Mode.CAMPAIGN
var current_mission_index: int = 0
var highest_unlocked_mission: int = 0
var last_score: int = 0
var last_won: bool = false
var session_score: int = 0
## Best clear rank per mission index ("", "C", "B", "A", "S").
var best_ranks: Array[String] = []
## Best score per mission index (campaign wins only).
var best_scores: Array[int] = []
## Best Boss Rush score.
var boss_rush_high_score: int = 0
var boss_rush_index: int = 0
## Live combo chain state.
var run_combo: int = 0
var run_combo_timer: float = 0.0

var settings_return_scene: String = "res://scenes/ui/main_menu.tscn"
var hangar_return_scene: String = "res://scenes/ui/main_menu.tscn"

## Settings (0–1 volumes, 0.5–1.5 touch sensitivity).
var music_volume: float = 0.75
var sfx_volume: float = 0.85
var touch_sensitivity: float = 1.0

## Accessibility settings.
var shake_intensity: float = 1.0
var reduce_flashes: bool = false
var show_pickup_labels: bool = false

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
var run_max_combo: int = 0
var run_grazes: int = 0
## Letter rank from the last finished run ("" while in progress).
var last_rank: String = ""
var last_rank_bonus: int = 0
## Graze + combo chain bonus from the last finished run.
var last_chain_bonus: int = 0

## Hangar: spendable credits, owned hulls, equipped ship, per-hull upgrades.
## Meta-progression is ships + upgrades — there is no player XP / account level.
var credits: int = 0
var selected_ship_id: String = Ships.STARTER_ID
var owned_ship_ids: PackedStringArray = PackedStringArray([Ships.STARTER_ID])
## ship_id -> { hull, thrust, cannon, core } ranks 0..MAX_UPGRADE
var upgrade_ranks: Dictionary = {}
var last_credits_earned: int = 0


func _ready() -> void:
	_ensure_rank_slots()
	_ensure_score_slots()
	load_progress()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.pickup_collected.connect(_on_pickup_collected)
	EventBus.formation_cleared.connect(_on_formation_cleared)
	EventBus.player_hull_hit.connect(_on_player_hull_hit)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.graze_occurred.connect(_on_graze)


func _process(delta: float) -> void:
	if run_active:
		run_elapsed += delta
		if run_combo > 0:
			run_combo_timer -= delta
			if run_combo_timer <= 0.0:
				run_combo = 0
				EventBus.combo_changed.emit(0)


func _ensure_rank_slots() -> void:
	while best_ranks.size() < MISSION_PATHS.size():
		best_ranks.append("")


func _ensure_score_slots() -> void:
	while best_scores.size() < MISSION_PATHS.size():
		best_scores.append(0)


func load_progress() -> void:
	_ensure_rank_slots()
	_ensure_score_slots()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_ensure_hangar()
		return
	highest_unlocked_mission = int(cfg.get_value("campaign", "unlocked", 0))
	boss_rush_high_score = int(cfg.get_value("boss_rush", "high_score", 0))
	music_volume = float(cfg.get_value("settings", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", sfx_volume))
	touch_sensitivity = float(cfg.get_value("settings", "touch_sensitivity", touch_sensitivity))
	shake_intensity = float(cfg.get_value("settings", "shake_intensity", shake_intensity))
	reduce_flashes = bool(cfg.get_value("settings", "reduce_flashes", reduce_flashes))
	show_pickup_labels = bool(cfg.get_value("settings", "show_pickup_labels", show_pickup_labels))
	for i in MISSION_PATHS.size():
		best_ranks[i] = String(cfg.get_value("ranks", "m%d" % i, ""))
		best_scores[i] = int(cfg.get_value("scores", "m%d" % i, 0))
	var seeded := _load_hangar(cfg)
	_ensure_hangar()
	if seeded:
		save_progress()


func save_progress() -> void:
	_ensure_rank_slots()
	_ensure_score_slots()
	_ensure_hangar()
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked", highest_unlocked_mission)
	cfg.set_value("boss_rush", "high_score", boss_rush_high_score)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "touch_sensitivity", touch_sensitivity)
	cfg.set_value("settings", "shake_intensity", shake_intensity)
	cfg.set_value("settings", "reduce_flashes", reduce_flashes)
	cfg.set_value("settings", "show_pickup_labels", show_pickup_labels)
	for i in MISSION_PATHS.size():
		cfg.set_value("ranks", "m%d" % i, best_ranks[i])
		cfg.set_value("scores", "m%d" % i, best_scores[i])
	cfg.set_value("hangar", "credits", credits)
	cfg.set_value("hangar", "selected", selected_ship_id)
	cfg.set_value("hangar", "owned", ",".join(owned_ship_ids))
	for id in Ships.all_ids():
		cfg.set_value("upgrades", id, Ships.format_ranks(get_ship_ranks(id)))
	cfg.save(SAVE_PATH)


func reset_hangar() -> void:
	credits = 0
	selected_ship_id = Ships.STARTER_ID
	owned_ship_ids = PackedStringArray([Ships.STARTER_ID])
	upgrade_ranks.clear()
	last_credits_earned = 0


func _ensure_hangar() -> void:
	if selected_ship_id.strip_edges() == "":
		selected_ship_id = Ships.STARTER_ID
	if Ships.get_def(selected_ship_id).is_empty():
		selected_ship_id = Ships.STARTER_ID
	if not owned_ship_ids.has(Ships.STARTER_ID):
		var owned: PackedStringArray = [Ships.STARTER_ID]
		for id in owned_ship_ids:
			if id != Ships.STARTER_ID and not owned.has(id):
				owned.append(id)
		owned_ship_ids = owned
	if not is_ship_owned(selected_ship_id):
		selected_ship_id = Ships.STARTER_ID


func _load_hangar(cfg: ConfigFile) -> bool:
	if not cfg.has_section("hangar"):
		reset_hangar()
		for score in best_scores:
			credits += Ships.credits_from_score(int(score))
		credits += Ships.credits_from_score(boss_rush_high_score)
		return true
	credits = maxi(0, int(cfg.get_value("hangar", "credits", 0)))
	selected_ship_id = String(cfg.get_value("hangar", "selected", Ships.STARTER_ID))
	owned_ship_ids = PackedStringArray()
	var owned_raw := String(cfg.get_value("hangar", "owned", Ships.STARTER_ID))
	for part in owned_raw.split(",", false):
		var id := String(part).strip_edges()
		if id != "" and not owned_ship_ids.has(id):
			owned_ship_ids.append(id)
	upgrade_ranks.clear()
	for id in Ships.all_ids():
		upgrade_ranks[id] = Ships.parse_ranks(String(cfg.get_value("upgrades", id, "0,0,0,0")))
	return false


func is_ship_owned(ship_id: String) -> bool:
	return owned_ship_ids.has(ship_id)


func get_ship_ranks(ship_id: String) -> Dictionary:
	return Ships.normalize_ranks(upgrade_ranks.get(ship_id, {}))


func get_loadout_for(ship_id: String) -> Dictionary:
	return Ships.resolve(ship_id, get_ship_ranks(ship_id))


func get_active_loadout() -> Dictionary:
	return get_loadout_for(selected_ship_id)


func equipped_ship_name() -> String:
	return String(get_active_loadout().get("name", "Striker"))


func buy_ship(ship_id: String) -> bool:
	var def := Ships.get_def(ship_id)
	if def.is_empty() or is_ship_owned(ship_id):
		return false
	var cost := int(def.get("cost", 0))
	if credits < cost:
		return false
	credits -= cost
	owned_ship_ids.append(ship_id)
	save_progress()
	return true


func select_ship(ship_id: String) -> bool:
	if not is_ship_owned(ship_id) or Ships.get_def(ship_id).is_empty():
		return false
	selected_ship_id = ship_id
	save_progress()
	return true


func buy_upgrade(ship_id: String, key: String) -> bool:
	if not is_ship_owned(ship_id) or not Ships.is_upgrade_key(key):
		return false
	var ranks := get_ship_ranks(ship_id)
	var rank := int(ranks.get(key, 0))
	if rank >= Ships.MAX_UPGRADE:
		return false
	var cost := Ships.upgrade_cost(rank)
	if cost <= 0 or credits < cost:
		return false
	credits -= cost
	ranks[key] = rank + 1
	upgrade_ranks[ship_id] = ranks
	save_progress()
	return true


func _award_run_credits() -> void:
	last_credits_earned = Ships.credits_from_score(session_score)
	if last_credits_earned > 0:
		credits += last_credits_earned


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	if AudioBus and AudioBus.has_method("apply_volumes"):
		AudioBus.apply_volumes()
	save_progress()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	if AudioBus and AudioBus.has_method("apply_volumes"):
		AudioBus.apply_volumes()
	save_progress()


func set_touch_sensitivity(v: float) -> void:
	touch_sensitivity = clampf(v, 0.5, 1.5)
	save_progress()


func set_shake_intensity(v: float) -> void:
	shake_intensity = clampf(v, 0.0, 1.0)
	save_progress()


func set_reduce_flashes(enabled: bool) -> void:
	reduce_flashes = enabled
	save_progress()


func set_show_pickup_labels(enabled: bool) -> void:
	show_pickup_labels = enabled
	save_progress()


func start_campaign_mission(index: int) -> void:
	mode = Mode.CAMPAIGN
	current_mission_index = clampi(index, 0, MISSION_PATHS.size() - 1)
	session_score = 0
	last_score = 0
	last_won = false
	last_rank = ""
	last_rank_bonus = 0
	last_chain_bonus = 0
	last_credits_earned = 0
	_reset_run_stats()


func start_boss_rush() -> void:
	mode = Mode.BOSS_RUSH
	boss_rush_index = 0
	current_mission_index = 0
	session_score = 0
	last_score = 0
	last_won = false
	last_rank = ""
	last_rank_bonus = 0
	last_chain_bonus = 0
	last_credits_earned = 0
	_reset_run_stats()


func boss_rush_count() -> int:
	return MISSION_PATHS.size()


func get_boss_rush_data(index: int = -1) -> MissionData:
	var i := boss_rush_index if index < 0 else index
	return get_mission_data(i)


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
	run_combo = 0
	run_combo_timer = 0.0
	run_max_combo = 0
	run_grazes = 0


func get_power_floor(mission_index: int = -1) -> int:
	## Minimum weapon tier on respawn. Stages are 1-based in design docs;
	## mission_index is 0-based (0–4 = Sector 1, 5–9 = Sector 2 / EX).
	var i := current_mission_index if mission_index < 0 else mission_index
	if mode == Mode.BOSS_RUSH:
		return 2
	if i < 0:
		return 1
	if i <= 2:
		return 1 ## Stages 1–3
	if i <= 4:
		return 2 ## Stages 4–5
	# Sector 2 / EX: Lv2 floor + utility on respawn.
	return 2


func is_ex_stage(mission_index: int = -1) -> bool:
	var i := current_mission_index if mission_index < 0 else mission_index
	return mode == Mode.CAMPAIGN and i >= SECTOR_1_COUNT


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
	last_chain_bonus = 0
	# Graze + combo chain bonus applies to any finished run.
	var chain_bonus := run_grazes * 30 + run_max_combo * 10
	if chain_bonus > 0:
		session_score += chain_bonus
		last_chain_bonus = chain_bonus
	if won and mode == Mode.CAMPAIGN:
		var rank_info := compute_clear_rank()
		last_rank = String(rank_info.get("rank", "C"))
		last_rank_bonus = int(rank_info.get("bonus", 0))
		if last_rank_bonus > 0:
			session_score += last_rank_bonus
		_record_best_rank(current_mission_index, last_rank)
		_record_best_score(current_mission_index, session_score)
		var next := current_mission_index + 1
		if next > highest_unlocked_mission and next < MISSION_PATHS.size():
			highest_unlocked_mission = next
		elif current_mission_index == MISSION_PATHS.size() - 1:
			highest_unlocked_mission = maxi(highest_unlocked_mission, current_mission_index)
	last_score = session_score
	_award_run_credits()
	if mode == Mode.BOSS_RUSH and session_score > boss_rush_high_score:
		boss_rush_high_score = session_score
	save_progress()


func _record_best_rank(index: int, rank: String) -> void:
	_ensure_rank_slots()
	if index < 0 or index >= best_ranks.size() or rank == "":
		return
	var prev := best_ranks[index]
	if prev == "" or RANK_ORDER.get(rank, 0) > RANK_ORDER.get(prev, 0):
		best_ranks[index] = rank


func _record_best_score(index: int, score: int) -> void:
	_ensure_score_slots()
	if index < 0 or index >= best_scores.size() or score <= 0:
		return
	if score > best_scores[index]:
		best_scores[index] = score


func get_best_score(index: int) -> int:
	_ensure_score_slots()
	if index < 0 or index >= best_scores.size():
		return 0
	return best_scores[index]


func get_best_rank(index: int) -> String:
	_ensure_rank_slots()
	if index < 0 or index >= best_ranks.size():
		return ""
	return best_ranks[index]


## Rank a campaign clear from hull hits, pace, aggression, and power ceiling.
## Returns { "rank": "S"|"A"|"B"|"C", "bonus": int, "points": int }.
func compute_clear_rank() -> Dictionary:
	var points := 0
	if run_hits_taken <= 0:
		points += 45
	elif run_hits_taken <= 2:
		points += 32
	elif run_hits_taken <= 5:
		points += 18
	elif run_hits_taken <= 9:
		points += 8
	if run_elapsed <= 150.0:
		points += 20
	elif run_elapsed <= 210.0:
		points += 12
	elif run_elapsed <= 270.0:
		points += 6
	# Stage 1 teaches formations; elsewhere reward kill aggression.
	if current_mission_index == 0 or current_mission_index == 5:
		if run_formations >= 4:
			points += 15
		elif run_formations >= 2:
			points += 8
		elif run_kills >= 50:
			points += 7
	else:
		if run_kills >= 80:
			points += 12
		elif run_kills >= 50:
			points += 7
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
	return format_seconds(run_elapsed)


func format_seconds(t: float) -> String:
	var total := int(t)
	return "%02d:%02d" % [total / 60, total % 60]


func is_mission_unlocked(index: int) -> bool:
	return index <= highest_unlocked_mission


func is_sector_unlocked(sector: int) -> bool:
	if sector <= SECTOR_1:
		return true
	# Sector 2 unlocks after clearing Flagship Core (index 4).
	return highest_unlocked_mission >= SECTOR_1_COUNT


func get_mission_data(index: int = -1) -> MissionData:
	var path := get_mission_path(index)
	if path == "":
		return null
	return load(path) as MissionData


func sector_of(index: int = -1) -> int:
	var data := get_mission_data(index)
	if data:
		return data.sector
	var i := current_mission_index if index < 0 else index
	return SECTOR_2 if i >= SECTOR_1_COUNT else SECTOR_1


func stage_of(index: int = -1) -> int:
	var data := get_mission_data(index)
	if data:
		return data.stage
	var i := current_mission_index if index < 0 else index
	return (i % SECTOR_1_COUNT) + 1


func is_sector_finale(index: int = -1) -> bool:
	## True for the last stage of whichever sector this mission belongs to.
	return stage_of(index) == SECTOR_1_COUNT


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
	_combo_gain()


## Graze near-misses: score + extend the chain.
func _on_graze() -> void:
	if not run_active:
		return
	run_grazes += 1
	_combo_gain()
	add_score(GRAZE_SCORE)


## Kills and grazes both bank one chain step; the chain multiplies returns.
func _combo_gain() -> void:
	run_combo += 1
	run_combo_timer = COMBO_WINDOW
	run_max_combo = maxi(run_max_combo, run_combo)
	if run_combo > 1:
		add_score(COMBO_BONUS_PER_KILL * (run_combo - 1))
	EventBus.combo_changed.emit(run_combo)


func _on_pickup_collected(_kind: String) -> void:
	if run_active:
		run_pickups += 1


func _on_formation_cleared(_center: Vector2, _size: int) -> void:
	if run_active:
		run_formations += 1


func _on_player_hull_hit() -> void:
	if run_active:
		run_hits_taken += 1
	# Getting tagged kills the chain.
	if run_combo > 0:
		run_combo = 0
		run_combo_timer = 0.0
		EventBus.combo_changed.emit(0)


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