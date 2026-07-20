extends SceneTree
## Validate critical scenes and resources load without errors.


func _init() -> void:
	var paths := [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/campaign_select.tscn",
		"res://scenes/ui/mission_results.tscn",
		"res://scenes/game/game_world.tscn",
		"res://scenes/entities/player.tscn",
		"res://scenes/entities/projectile.tscn",
		"res://scenes/entities/enemy_base.tscn",
		"res://scenes/entities/pickup.tscn",
		"res://resources/missions/mission_01_dawn_patrol.tres",
		"res://resources/missions/mission_02_debris_field.tres",
		"res://resources/missions/mission_03_nebula_core.tres",
		"res://resources/missions/mission_04_solar_flare.tres",
		"res://resources/missions/mission_05_frozen_belt.tres",
		"res://resources/missions/mission_06_event_horizon.tres",
		"res://resources/enemies/boss.tres",
		"res://resources/enemies/boss_elite.tres",
	]
	var ok := true
	for p in paths:
		var res = load(p)
		if res == null:
			push_error("FAILED to load: " + p)
			ok = false
		else:
			print("OK  ", p)
			if res is PackedScene:
				var inst = res.instantiate()
				if inst == null:
					push_error("FAILED instantiate: " + p)
					ok = false
				else:
					inst.free()
	if ok:
		print("VALIDATION PASSED")
	else:
		print("VALIDATION FAILED")
	quit(0 if ok else 1)
