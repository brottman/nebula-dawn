extends SceneTree
## Hangar catalog, buy/upgrade, credit awards, save seed, and player loadout.
## Stashes `user://nebula_dawn.cfg` so a local save is not overwritten.
## `--script` tools cannot name autoloads at compile time; use the tree node.

const Ships := preload("res://scripts/hangar/ship_catalog.gd")
const SAVE_PATH := "user://nebula_dawn.cfg"
const BACKUP_PATH := "user://nebula_dawn.cfg.hangar_test.bak"

var _ok := true
var _had_save := false
## GameState autoload (untyped so hangar methods resolve at runtime).
var gs


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	if not _stash():
		quit(1)
		return
	_test_catalog()
	_test_buy_and_upgrade()
	_test_run_credits()
	_test_old_save_seed()
	await _test_player_loadout()
	_restore()
	if _ok:
		print("HANGAR OK")
		quit(0)
	else:
		print("HANGAR FAILED")
		quit(1)


func _fail(msg: String) -> void:
	push_error(msg)
	_ok = false


func _stash() -> bool:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		var err := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH)
		)
		if err != OK:
			_fail("could not stash save: %s" % err)
			return false
	gs.reset_hangar()
	return true


func _restore() -> void:
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var bak_abs := ProjectSettings.globalize_path(BACKUP_PATH)
	if _had_save:
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.copy_absolute(bak_abs, save_abs)
			DirAccess.remove_absolute(bak_abs)
	else:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(save_abs)
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(bak_abs)
	gs.reset_hangar()
	gs.load_progress()
	gs.start_campaign_mission(0)


func _test_catalog() -> void:
	if Ships.STARTER_ID != "striker":
		_fail("starter should be striker")
	var ids := Ships.all_ids()
	if ids.size() != 5:
		_fail("expected 5 hulls, got %d" % ids.size())
	for id in ["striker", "interceptor", "aegis", "wraith", "dawn"]:
		if Ships.get_def(id).is_empty():
			_fail("missing hull def: " + id)
	if int(Ships.get_def("striker").get("cost", -1)) != 0:
		_fail("striker should be free")
	if int(Ships.get_def("interceptor").get("cost", 0)) != 2500:
		_fail("interceptor cost")
	if int(Ships.get_def("aegis").get("cost", 0)) != 5500:
		_fail("aegis cost")
	if int(Ships.get_def("wraith").get("cost", 0)) != 12000:
		_fail("wraith cost")
	if int(Ships.get_def("dawn").get("cost", 0)) != 24000:
		_fail("dawn cost")
	if Ships.credits_from_score(0) != 0 or Ships.credits_from_score(-10) != 0:
		_fail("credits_from_score should be 0 for non-positive scores")
	if Ships.credits_from_score(9) != 0 or Ships.credits_from_score(10) != 1:
		_fail("credits_from_score integer division")
	if Ships.credits_from_score(12345) != 1234:
		_fail("credits_from_score 12345")
	if Ships.format_credits(0) != "0" or Ships.format_credits(999) != "999":
		_fail("format_credits small")
	if Ships.format_credits(1000) != "1,000" or Ships.format_credits(1234567) != "1,234,567":
		_fail("format_credits commas")
	if Ships.upgrade_cost(0) != 400 or Ships.upgrade_cost(4) != 4000 or Ships.upgrade_cost(5) != 0:
		_fail("upgrade_cost ranks")
	var spec: Dictionary = Ships.resolve("striker", {
		"hull": 2, "thrust": 1, "cannon": 3, "core": 2,
	})
	if int(spec.get("max_hp", 0)) != 9:
		_fail("hull rank +1 HP, expected 9 got %s" % spec.get("max_hp"))
	if not is_equal_approx(float(spec.get("move_speed", 0.0)), 310.0 * 1.05):
		_fail("thrust +5%% speed")
	if not is_equal_approx(float(spec.get("bullet_damage", 0.0)), 1.24):
		_fail("cannon +8%% damage")
	if not is_equal_approx(float(spec.get("fire_cooldown", 0.0)), 0.16 * 0.92):
		_fail("core +4%% fire rate")
	var fallback: Dictionary = Ships.resolve("nope", {})
	if String(fallback.get("id", "")) != Ships.STARTER_ID:
		_fail("unknown hull should resolve to starter")
	var ranks := Ships.parse_ranks("2,1,5,9")
	if int(ranks["hull"]) != 2 or int(ranks["thrust"]) != 1:
		_fail("parse_ranks")
	if int(ranks["cannon"]) != 5 or int(ranks["core"]) != 5:
		_fail("parse_ranks should clamp to MAX_UPGRADE")
	if Ships.format_ranks({"hull": 2, "thrust": 1, "cannon": 5, "core": 5}) != "2,1,5,5":
		_fail("format_ranks")
	print("OK  hangar catalog")


func _test_buy_and_upgrade() -> void:
	gs.reset_hangar()
	if gs.buy_ship("interceptor"):
		_fail("buy_ship should fail without credits")
	if gs.select_ship("interceptor"):
		_fail("select_ship should fail when unowned")
	if gs.buy_upgrade("striker", "hull"):
		_fail("upgrade should fail without credits")
	if gs.buy_upgrade("interceptor", "hull"):
		_fail("upgrade should fail when hull unowned")
	gs.credits = 2500
	if not gs.buy_ship("interceptor"):
		_fail("buy_ship interceptor")
	if gs.credits != 0:
		_fail("buy_ship should spend 2500")
	if not gs.is_ship_owned("interceptor"):
		_fail("interceptor not owned after buy")
	if gs.buy_ship("interceptor"):
		_fail("cannot buy owned hull")
	if not gs.select_ship("interceptor"):
		_fail("select_ship interceptor")
	if gs.selected_ship_id != "interceptor":
		_fail("selected_ship_id")
	if gs.select_ship("aegis"):
		_fail("cannot select unowned aegis")
	if gs.buy_ship("nope") or gs.select_ship("nope"):
		_fail("unknown hull should reject buy/select")
	gs.reset_hangar()
	gs.credits = 400
	if not gs.buy_upgrade("striker", "hull"):
		_fail("first hull upgrade")
	if int(gs.get_ship_ranks("striker").get("hull", 0)) != 1:
		_fail("hull rank after first buy")
	if gs.credits != 0:
		_fail("first upgrade should spend 400")
	gs.credits = 900
	if not gs.buy_upgrade("striker", "hull"):
		_fail("second hull upgrade")
	if int(gs.get_ship_ranks("striker").get("hull", 0)) != 2:
		_fail("hull rank 2")
	gs.credits = 999999
	for _i in Ships.MAX_UPGRADE:
		if not gs.buy_upgrade("striker", "cannon"):
			_fail("cannon upgrade toward max")
			break
	if int(gs.get_ship_ranks("striker").get("cannon", 0)) != Ships.MAX_UPGRADE:
		_fail("cannon should be maxed")
	if gs.buy_upgrade("striker", "cannon"):
		_fail("cannot upgrade past max")
	if gs.buy_upgrade("striker", "nope"):
		_fail("unknown upgrade key")
	print("OK  hangar buy/upgrade")


func _test_run_credits() -> void:
	gs.reset_hangar()
	gs.start_campaign_mission(0)
	gs.session_score = 12345
	gs.record_mission_result(false)
	if gs.last_credits_earned != 1234:
		_fail("loss credits earned, got %d" % gs.last_credits_earned)
	if gs.credits != 1234:
		_fail("loss credits bank, got %d" % gs.credits)
	var bank: int = gs.credits
	gs.start_campaign_mission(0)
	gs.session_score = 200
	gs.run_hits_taken = 99
	gs.run_elapsed = 999.0
	gs.record_mission_result(true)
	## Rank C bonus 500 → session 700 → 70 credits.
	if gs.last_credits_earned != 70:
		_fail("win credits should include rank bonus, got %d" % gs.last_credits_earned)
	if gs.credits != bank + 70:
		_fail("win should add to bank")
	gs.reset_hangar()
	gs.start_campaign_mission(1)
	gs.session_score = 800
	gs.record_mission_result(false)
	if gs.last_credits_earned != 80 or gs.credits != 80:
		_fail("campaign should award credits")
	print("OK  hangar run credits")


func _test_old_save_seed() -> void:
	gs.reset_hangar()
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked", 2)
	cfg.set_value("scores", "m0", 10000)
	cfg.set_value("scores", "m1", 250)
	cfg.save(SAVE_PATH)
	gs.load_progress()
	var expected := Ships.credits_from_score(10000) + Ships.credits_from_score(250)
	if gs.credits != expected:
		_fail("old save seed credits %d != %d" % [gs.credits, expected])
	if not gs.is_ship_owned(Ships.STARTER_ID):
		_fail("seeded save should own starter")
	var seeded_bank: int = gs.credits
	gs.credits = 0
	gs.load_progress()
	if gs.credits != seeded_bank:
		_fail("hangar section should not re-seed (got %d)" % gs.credits)
	print("OK  hangar save seed")


func _test_player_loadout() -> void:
	gs.reset_hangar()
	gs.start_campaign_mission(0)
	gs.credits = 5500
	if not gs.buy_ship("aegis") or not gs.select_ship("aegis"):
		_fail("could not equip aegis for loadout test")
		return
	var packed: PackedScene = load("res://scenes/entities/player.tscn")
	if packed == null:
		_fail("player.tscn missing")
		return
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame
	if int(player.max_hp) != 10:
		_fail("aegis max_hp, got %s" % player.max_hp)
	if int(player.lives) != 4:
		_fail("aegis lives, got %s" % player.lives)
	if int(player.shield_charges) != 1:
		_fail("aegis start shield, got %s" % player.shield_charges)
	if not is_equal_approx(float(player.move_speed), 255.0):
		_fail("aegis move_speed, got %s" % player.move_speed)
	if not is_equal_approx(float(player.fire_cooldown), 0.19):
		_fail("aegis fire_cooldown, got %s" % player.fire_cooldown)
	player.queue_free()
	await process_frame
	gs.reset_hangar()
	gs.credits = 2500
	gs.buy_ship("interceptor")
	gs.select_ship("interceptor")
	gs.credits = 400
	gs.buy_upgrade("interceptor", "core")
	player = packed.instantiate()
	root.add_child(player)
	await process_frame
	var expected_cd := maxf(Ships.MIN_FIRE_COOLDOWN, 0.13 * 0.96)
	if not is_equal_approx(float(player.fire_cooldown), expected_cd):
		_fail("interceptor core fire_cooldown, got %s" % player.fire_cooldown)
	var weapons: Node = player.get("weapons")
	if weapons and weapons.has_method("_weapon_cooldown"):
		var blaster_cd := float(weapons.call("_weapon_cooldown"))
		if not is_equal_approx(blaster_cd, expected_cd):
			_fail("blaster cd should scale with hull, got %s" % blaster_cd)
	else:
		_fail("WeaponSystem._weapon_cooldown missing")
	player.queue_free()
	print("OK  hangar player loadout")