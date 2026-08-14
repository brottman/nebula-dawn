extends SceneTree
## Validate scenes, missions, archetypes, sprites, and HUD wiring.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var ok := true
	ok = _check_paths() and ok
	ok = _check_autoloads() and ok
	ok = _check_hangar() and ok
	ok = _check_player_scene() and ok
	ok = _check_missions() and ok
	ok = _check_gimmicks() and ok
	ok = _check_sprites() and ok
	ok = _check_music() and ok
	ok = await _check_pause_overlay() and ok
	if ok:
		print("VALIDATION PASSED")
		quit(0)
	else:
		print("VALIDATION FAILED")
		quit(1)


func _fail(msg: String) -> void:
	push_error(msg)


func _check_paths() -> bool:
	var paths := [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/campaign_select.tscn",
		"res://scenes/ui/hangar.tscn",
		"res://scenes/ui/mission_results.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/game/game_world.tscn",
		"res://scenes/game/hud.tscn",
		"res://scenes/game/pause_menu.tscn",
		"res://scenes/entities/player.tscn",
		"res://scenes/entities/projectile.tscn",
		"res://scenes/entities/enemy_base.tscn",
		"res://scenes/entities/pickup.tscn",
		"res://resources/missions/mission_01_planetary_ascent.tres",
		"res://resources/missions/mission_02_asteroid_belt.tres",
		"res://resources/missions/mission_03_nebula_anomaly.tres",
		"res://resources/missions/mission_04_cybernetic_hive.tres",
		"res://resources/missions/mission_05_flagship_core.tres",
		"res://resources/missions/mission_06_mirror_field.tres",
		"res://resources/missions/mission_07_ion_storm.tres",
		"res://resources/missions/mission_08_phantom_wake.tres",
		"res://resources/missions/mission_09_scrap_gauntlet.tres",
		"res://resources/missions/mission_10_dawn_gate.tres",
		"res://resources/enemies/boss.tres",
		"res://resources/enemies/boss_elite.tres",
		"res://resources/enemies/mid_boss.tres",
		"res://scenes/stage/barrier.tscn",
		"res://scenes/stage/terminal.tscn",
		"res://scenes/stage/singularity.tscn",
		"res://assets/audio/sfx/shoot.wav",
		"res://assets/audio/sfx/explode.wav",
	]
	var ok := true
	for p in paths:
		var res = load(p)
		if res == null:
			_fail("FAILED to load: " + p)
			ok = false
			continue
		print("OK  ", p)
		if res is PackedScene:
			var inst = res.instantiate()
			if inst == null:
				_fail("FAILED instantiate: " + p)
				ok = false
			else:
				inst.free()
	return ok


func _check_autoloads() -> bool:
	var ok := true
	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	var ab := root.get_node_or_null("AudioBus")
	if gs == null:
		_fail("GameState autoload missing")
		ok = false
	if ab == null:
		_fail("AudioBus autoload missing")
		ok = false
	if eb == null:
		_fail("EventBus autoload missing")
		return false
	for sig in [
		"score_changed",
		"player_lives_changed",
		"weapon_tier_changed",
		"player_hp_changed",
		"bomb_stock_changed",
		"overdrive_changed",
		"pause_requested",
	]:
		if not eb.has_signal(sig):
			_fail("EventBus missing signal: " + sig)
			ok = false
	return ok


func _check_player_scene() -> bool:
	var packed: PackedScene = load("res://scenes/entities/player.tscn")
	if packed == null:
		_fail("player.tscn missing")
		return false
	var player: Node = packed.instantiate()
	var ok := true
	if player.get_node_or_null("WeaponSystem") == null:
		_fail("player.tscn missing WeaponSystem child")
		ok = false
	if player.get_node_or_null("LifeSystem") == null:
		_fail("player.tscn missing LifeSystem child")
		ok = false
	for method_name in [
		"apply_pickup",
		"apply_hangar_loadout",
		"try_use_bomb",
		"_emit_weapon_changed",
		"_try_death_bomb",
		"take_damage",
		"play_victory_exit",
	]:
		if not player.has_method(method_name):
			_fail("player facade missing method: " + method_name)
			ok = false
	player.free()
	return ok


func _check_missions() -> bool:
	var expected := [
		{&"gimmick": &"formations", &"boss": &"orbital", &"mid": &"transport"},
		{&"gimmick": &"asteroids", &"boss": &"megalith", &"mid": &"drill"},
		{&"gimmick": &"nebula", &"boss": &"leviathan", &"mid": &"stalker"},
		{&"gimmick": &"hive", &"boss": &"fabrication", &"mid": &"overseer"},
		{&"gimmick": &"gravity", &"boss": &"omega", &"mid": &"ace"},
		{&"gimmick": &"mirrors", &"boss": &"kaleidoscope", &"mid": &"prism"},
		{&"gimmick": &"ion", &"boss": &"tempest", &"mid": &"coil"},
		{&"gimmick": &"phantoms", &"boss": &"choir", &"mid": &"echo"},
		{&"gimmick": &"scrap", &"boss": &"junkyard", &"mid": &"tyrant"},
		{&"gimmick": &"flare", &"boss": &"dawn", &"mid": &"herald"},
	]
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		_fail("GameState missing; cannot check missions")
		return false
	var paths: Array = gs.get("MISSION_PATHS")
	if paths.size() != expected.size():
		_fail("MISSION_PATHS size %d != %d" % [paths.size(), expected.size()])
		return false
	var ok := true
	for i in expected.size():
		var path: String = String(paths[i])
		var data: MissionData = load(path) as MissionData
		if data == null:
			_fail("Mission failed to load: " + path)
			ok = false
			continue
		var exp: Dictionary = expected[i]
		if data.gimmick_id != exp[&"gimmick"]:
			_fail("%s gimmick_id=%s expected %s" % [path, data.gimmick_id, exp[&"gimmick"]])
			ok = false
		if data.boss == null:
			_fail("%s missing stage boss" % path)
			ok = false
		else:
			if data.boss.boss_archetype != exp[&"boss"]:
				_fail("%s boss archetype=%s expected %s" % [path, data.boss.boss_archetype, exp[&"boss"]])
				ok = false
			if data.boss.scene_path != "res://scenes/entities/enemy_base.tscn":
				_fail("%s boss scene_path=%s" % [path, data.boss.scene_path])
				ok = false
		var mid := _find_mid(data)
		if mid == null:
			_fail("%s missing mid-boss" % path)
			ok = false
		elif mid.boss_archetype != exp[&"mid"]:
			_fail("%s mid archetype=%s expected %s" % [path, mid.boss_archetype, exp[&"mid"]])
			ok = false
		else:
			print("OK  mission[%d] %s / %s / %s" % [i, data.gimmick_id, data.boss.boss_archetype, mid.boss_archetype])
	return ok


func _find_mid(data: MissionData) -> EnemyStats:
	for wave in data.waves:
		for entry in wave.entries:
			if entry.enemy and entry.enemy.is_mid_boss:
				return entry.enemy
	return null


func _check_gimmicks() -> bool:
	var expected := {
		&"formations": "res://scripts/stage/gimmicks/formations.gd",
		&"asteroids": "res://scripts/stage/gimmicks/asteroids.gd",
		&"nebula": "res://scripts/stage/gimmicks/nebula.gd",
		&"hive": "res://scripts/stage/gimmicks/hive.gd",
		&"gravity": "res://scripts/stage/gimmicks/gravity.gd",
		&"mirrors": "res://scripts/stage/gimmicks/mirrors.gd",
		&"ion": "res://scripts/stage/gimmicks/ion.gd",
		&"phantoms": "res://scripts/stage/gimmicks/phantoms.gd",
		&"scrap": "res://scripts/stage/gimmicks/scrap.gd",
		&"flare": "res://scripts/stage/gimmicks/flare.gd",
	}
	var ok := true
	for id in expected.keys():
		var path: String = expected[id]
		var script: Script = load(path)
		if script == null:
			_fail("Missing gimmick script %s -> %s" % [id, path])
			ok = false
			continue
		var node := Node.new()
		node.set_script(script)
		for method_name in ["bind", "begin", "tick", "cleanup"]:
			if not node.has_method(method_name):
				_fail("Gimmick %s missing StageGimmick API: %s" % [id, method_name])
				ok = false
				break
		node.free()
	return ok


func _check_hangar() -> bool:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		_fail("GameState missing; cannot check hangar")
		return false
	var ok := true
	for method_name in [
		"reset_hangar",
		"buy_ship",
		"select_ship",
		"buy_upgrade",
		"get_active_loadout",
		"equipped_ship_name",
		"is_ship_owned",
	]:
		if not gs.has_method(method_name):
			_fail("GameState missing hangar method: " + method_name)
			ok = false
	var Ships := load("res://scripts/hangar/ship_catalog.gd")
	if Ships == null:
		_fail("ship_catalog.gd missing")
		return false
	if String(Ships.STARTER_ID) != "striker":
		_fail("ShipCatalog.STARTER_ID")
		ok = false
	if Ships.all_ids().size() != 5:
		_fail("ShipCatalog roster size %d" % Ships.all_ids().size())
		ok = false
	var hangar: Node = load("res://scenes/ui/hangar.tscn").instantiate()
	for path in [
		"VBox/Credits",
		"VBox/Scroll/Content/ShipList",
		"VBox/Scroll/Content/Portrait",
		"VBox/Scroll/Content/ActionButton",
		"VBox/Scroll/Content/UpgradeList",
		"VBox/BackButton",
	]:
		if hangar.get_node_or_null(path) == null:
			_fail("hangar.tscn missing " + path)
			ok = false
	hangar.free()
	var campaign: Node = load("res://scenes/ui/campaign_select.tscn").instantiate()
	for path in ["Center/VBox/HangarStatus", "Center/VBox/HangarButton"]:
		if campaign.get_node_or_null(path) == null:
			_fail("campaign_select.tscn missing " + path)
			ok = false
	campaign.free()
	var results: Node = load("res://scenes/ui/mission_results.tscn").instantiate()
	for path in ["Scroll/VBox/Credits", "Scroll/VBox/HangarButton"]:
		if results.get_node_or_null(path) == null:
			_fail("mission_results.tscn missing " + path)
			ok = false
	results.free()
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	for path in ["Center/VBox/HangarButton", "Center/VBox/Credits"]:
		if menu.get_node_or_null(path) == null:
			_fail("main_menu.tscn missing " + path)
			ok = false
	menu.free()
	if ok:
		print("OK  hangar scenes + catalog")
	return ok


func _check_sprites() -> bool:
	var paths := [
		"res://assets/sprites/player_ship.svg",
		"res://assets/sprites/player_interceptor.svg",
		"res://assets/sprites/player_aegis.svg",
		"res://assets/sprites/player_wraith.svg",
		"res://assets/sprites/player_dawn.svg",
		"res://assets/sprites/enemy_boss_kaleidoscope.svg",
		"res://assets/sprites/enemy_boss_tempest.svg",
		"res://assets/sprites/enemy_boss_choir.svg",
		"res://assets/sprites/enemy_boss_junkyard.svg",
		"res://assets/sprites/enemy_boss_dawn.svg",
		"res://assets/sprites/enemy_mid_transport.svg",
		"res://assets/sprites/enemy_mid_prism.svg",
		"res://assets/sprites/enemy_mid_coil.svg",
		"res://assets/sprites/enemy_mid_echo.svg",
		"res://assets/sprites/enemy_mid_tyrant.svg",
		"res://assets/sprites/enemy_mid_herald.svg",
	]
	var ok := true
	for p in paths:
		if not FileAccess.file_exists(p):
			_fail("Missing sprite: " + p)
			ok = false
	return ok


func _check_music() -> bool:
	var ab := root.get_node_or_null("AudioBus")
	if ab == null:
		return false
	var ok := true
	var tracks: Array = ab.get("MISSION_MUSIC")
	if tracks.size() < 10:
		_fail("AudioBus.MISSION_MUSIC has %d entries" % tracks.size())
		ok = false
	for p in tracks:
		if not FileAccess.file_exists(String(p)):
			_fail("Missing music: " + String(p))
			ok = false
	return ok


func _check_pause_overlay() -> bool:
	var packed: PackedScene = load("res://scenes/game/pause_menu.tscn")
	if packed == null:
		_fail("pause_menu.tscn missing")
		return false
	var pause: Node = packed.instantiate()
	root.add_child(pause)
	await process_frame
	if not pause.has_method("show_menu") or not pause.has_method("is_settings_open"):
		_fail("pause_menu missing overlay API")
		pause.queue_free()
		return false
	pause.call("show_menu")
	pause.call("_on_settings")
	await process_frame
	var ok := true
	if not bool(pause.call("is_settings_open")):
		_fail("pause Settings did not overlay")
		ok = false
	else:
		var settings: Node = pause.get("_settings")
		if settings == null or settings.get("overlay_mode") != true:
			_fail("settings overlay_mode was not true")
			ok = false
		print("OK  pause settings overlay")
	pause.queue_free()
	return ok