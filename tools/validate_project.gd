extends SceneTree
## Validate critical scenes and resources load without errors.


func _init() -> void:
	var paths := [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/campaign_select.tscn",
		"res://scenes/ui/practice_select.tscn",
		"res://scenes/ui/records.tscn",
		"res://scenes/ui/mission_results.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/game/game_world.tscn",
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
