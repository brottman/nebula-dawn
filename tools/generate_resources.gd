extends SceneTree
## Headless generator: creates enemy + mission .tres resources.
## Run: godot --headless --path . --script res://tools/generate_resources.gd


func _init() -> void:
	_ensure_dirs()
	var scout := _enemy(&"scout", "Scout", 2.0, 140.0, 100, 0.0, Color(1.0, 0.45, 0.45), Vector2(26, 26))
	var strafer := _enemy(&"strafer", "Strafer", 3.0, 110.0, 150, 1.4, Color(1.0, 0.7, 0.35), Vector2(30, 24))
	strafer.projectile_speed = 240.0
	var drone := _enemy(&"drone", "Drone", 6.0, 70.0, 200, 1.8, Color(0.7, 0.4, 1.0), Vector2(34, 34))
	drone.projectile_speed = 200.0
	var asteroid := _enemy(&"asteroid", "Asteroid", 4.0, 90.0, 50, 0.0, Color(0.55, 0.5, 0.48), Vector2(36, 36))
	asteroid.is_hazard = true
	asteroid.contact_damage = 1
	var boss := _enemy(&"boss", "Nebula Core", 80.0, 60.0, 5000, 1.1, Color(1.0, 0.35, 0.55), Vector2(90, 70))
	boss.is_boss = true
	boss.projectile_speed = 260.0
	boss.contact_damage = 2
	var boss_elite := _enemy(&"boss", "Void Maw", 140.0, 70.0, 8000, 0.9, Color(0.75, 0.3, 1.0), Vector2(100, 78))
	boss_elite.is_boss = true
	boss_elite.projectile_speed = 300.0
	boss_elite.contact_damage = 2

	_save(scout, "res://resources/enemies/scout.tres")
	_save(strafer, "res://resources/enemies/strafer.tres")
	_save(drone, "res://resources/enemies/drone.tres")
	_save(asteroid, "res://resources/enemies/asteroid.tres")
	_save(boss, "res://resources/enemies/boss.tres")
	_save(boss_elite, "res://resources/enemies/boss_elite.tres")

	_save(_mission_01(scout, strafer), "res://resources/missions/mission_01_dawn_patrol.tres")
	_save(_mission_02(scout, strafer, asteroid, drone), "res://resources/missions/mission_02_debris_field.tres")
	_save(_mission_03(scout, strafer, drone, boss), "res://resources/missions/mission_03_nebula_core.tres")
	_save(_mission_04(scout, strafer, drone), "res://resources/missions/mission_04_solar_flare.tres")
	_save(_mission_05(scout, strafer, asteroid, drone), "res://resources/missions/mission_05_frozen_belt.tres")
	_save(_mission_06(scout, strafer, asteroid, drone, boss_elite), "res://resources/missions/mission_06_event_horizon.tres")

	print("Nebula Dawn resources generated.")
	quit()


func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources/enemies")
	DirAccess.make_dir_recursive_absolute("res://resources/missions")


func _enemy(id: StringName, display: String, hp: float, speed: float, score: int, fire: float, color: Color, size: Vector2) -> EnemyStats:
	var e := EnemyStats.new()
	e.enemy_id = id
	e.display_name = display
	e.max_hp = hp
	e.move_speed = speed
	e.score_value = score
	e.fire_interval = fire
	e.color = color
	e.size = size
	e.scene_path = "res://scenes/entities/enemy_base.tscn"
	return e


func _entry(enemy: EnemyStats, delay: float, pos: Vector2, count: int = 1, spacing: Vector2 = Vector2(48, 0)) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = enemy
	s.delay = delay
	s.position = pos
	s.count = count
	s.spacing = spacing
	return s


func _wave(label: String, start: float, entries: Array[SpawnEntry], clear := true) -> WaveDef:
	var w := WaveDef.new()
	w.label = label
	w.start_delay = start
	w.entries = entries
	w.clear_required = clear
	return w


func _mission_01(scout: EnemyStats, strafer: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_01"
	m.title = "Dawn Patrol"
	m.subtitle = "Clear the outer patrol routes."
	m.scroll_speed = 35.0
	m.background_tint = Color(0.15, 0.25, 0.55)
	m.win_on_waves_cleared = true
	m.waves = [
		_wave("Intro", 0.8, [
			_entry(scout, 0.0, Vector2(240, -40)),
			_entry(scout, 0.6, Vector2(160, -40)),
			_entry(scout, 0.0, Vector2(320, -40)),
		]),
		_wave("Line", 0.6, [
			_entry(scout, 0.0, Vector2(120, -40), 4, Vector2(70, 0)),
		]),
		_wave("Strafers", 0.5, [
			_entry(strafer, 0.0, Vector2(100, -40)),
			_entry(strafer, 0.4, Vector2(380, -40)),
			_entry(scout, 0.8, Vector2(240, -40), 3, Vector2(60, 0)),
		]),
		_wave("Finale", 0.5, [
			_entry(scout, 0.0, Vector2(80, -40), 3, Vector2(50, 20)),
			_entry(strafer, 0.5, Vector2(240, -40), 2, Vector2(100, 0)),
			_entry(scout, 0.8, Vector2(360, -40), 2, Vector2(-40, 30)),
		]),
	]
	return m


func _mission_02(scout: EnemyStats, strafer: EnemyStats, asteroid: EnemyStats, drone: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_02"
	m.title = "Debris Field"
	m.subtitle = "Weave through rock and fighters."
	m.scroll_speed = 48.0
	m.background_tint = Color(0.28, 0.18, 0.12)
	m.waves = [
		_wave("Rocks", 0.6, [
			_entry(asteroid, 0.0, Vector2(120, -40)),
			_entry(asteroid, 0.3, Vector2(280, -50)),
			_entry(asteroid, 0.3, Vector2(400, -30)),
			_entry(scout, 0.6, Vector2(200, -40), 2, Vector2(80, 0)),
		]),
		_wave("Zigzag", 0.5, [
			_entry(strafer, 0.0, Vector2(90, -40), 3, Vector2(0, 40)),
			_entry(strafer, 0.2, Vector2(390, -40), 3, Vector2(0, 40)),
			_entry(asteroid, 0.8, Vector2(240, -40), 2, Vector2(90, 20)),
		]),
		_wave("Heavies", 0.5, [
			_entry(drone, 0.0, Vector2(240, -40)),
			_entry(scout, 0.5, Vector2(140, -40), 3, Vector2(100, 0)),
			_entry(asteroid, 0.4, Vector2(60, -40)),
			_entry(asteroid, 0.0, Vector2(420, -40)),
		]),
		_wave("Storm", 0.4, [
			_entry(asteroid, 0.0, Vector2(100, -40), 3, Vector2(120, 15)),
			_entry(strafer, 0.3, Vector2(200, -40), 2, Vector2(80, 0)),
			_entry(drone, 0.6, Vector2(320, -40)),
			_entry(scout, 0.4, Vector2(160, -40), 4, Vector2(55, 10)),
		]),
	]
	return m


func _mission_03(scout: EnemyStats, strafer: EnemyStats, drone: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_03"
	m.title = "Nebula Core"
	m.subtitle = "Breach the heart of the storm."
	m.scroll_speed = 55.0
	m.background_tint = Color(0.35, 0.08, 0.28)
	m.boss = boss
	m.boss_intro_delay = 1.8
	m.waves = [
		_wave("Elite Guard", 0.7, [
			_entry(strafer, 0.0, Vector2(120, -40), 2, Vector2(80, 0)),
			_entry(drone, 0.4, Vector2(300, -40)),
			_entry(scout, 0.5, Vector2(200, -40), 3, Vector2(50, 0)),
		]),
		_wave("Crossfire", 0.5, [
			_entry(strafer, 0.0, Vector2(80, -40), 3, Vector2(0, 35)),
			_entry(strafer, 0.0, Vector2(400, -40), 3, Vector2(0, 35)),
			_entry(drone, 0.8, Vector2(240, -40), 2, Vector2(100, 0)),
		]),
		_wave("Before the Core", 0.5, [
			_entry(scout, 0.0, Vector2(100, -40), 5, Vector2(60, 8)),
			_entry(drone, 0.6, Vector2(180, -40)),
			_entry(drone, 0.2, Vector2(340, -40)),
			_entry(strafer, 0.5, Vector2(240, -40), 2, Vector2(90, 0)),
		]),
	]
	return m


func _mission_04(scout: EnemyStats, strafer: EnemyStats, drone: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_04"
	m.title = "Solar Flare"
	m.subtitle = "Ride the burning stellar winds."
	m.scroll_speed = 65.0
	m.background_tint = Color(0.5, 0.2, 0.08)
	m.waves = [
		_wave("Ignition", 0.7, [
			_entry(strafer, 0.0, Vector2(140, -40)),
			_entry(strafer, 0.4, Vector2(340, -40)),
			_entry(scout, 0.8, Vector2(240, -40), 3, Vector2(60, 0)),
		]),
		_wave("Flare Jets", 0.5, [
			_entry(strafer, 0.0, Vector2(80, -40), 3, Vector2(0, 40)),
			_entry(strafer, 0.3, Vector2(400, -40), 3, Vector2(0, 40)),
			_entry(scout, 0.9, Vector2(240, -60), 2, Vector2(80, 0)),
		]),
		_wave("Corona", 0.5, [
			_entry(drone, 0.0, Vector2(240, -40)),
			_entry(drone, 0.5, Vector2(140, -50)),
			_entry(drone, 0.3, Vector2(340, -50)),
			_entry(scout, 0.6, Vector2(120, -40), 3, Vector2(120, 10)),
		]),
		_wave("Sunstorm", 0.4, [
			_entry(strafer, 0.0, Vector2(100, -40), 2, Vector2(60, 0)),
			_entry(strafer, 0.4, Vector2(380, -40), 2, Vector2(-60, 0)),
			_entry(drone, 0.8, Vector2(240, -40)),
			_entry(scout, 0.6, Vector2(240, -80), 4, Vector2(45, 0)),
		]),
		_wave("Superflare", 0.4, [
			_entry(drone, 0.0, Vector2(180, -40)),
			_entry(drone, 0.2, Vector2(300, -40)),
			_entry(strafer, 0.5, Vector2(90, -40), 3, Vector2(0, 35)),
			_entry(strafer, 0.5, Vector2(390, -40), 3, Vector2(0, 35)),
			_entry(scout, 1.0, Vector2(240, -40), 5, Vector2(55, 8)),
		]),
	]
	return m


func _mission_05(scout: EnemyStats, strafer: EnemyStats, asteroid: EnemyStats, drone: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_05"
	m.title = "Frozen Belt"
	m.subtitle = "Drift through the silent ice field."
	m.scroll_speed = 28.0
	m.background_tint = Color(0.12, 0.3, 0.45)
	m.waves = [
		_wave("Ice Shards", 0.7, [
			_entry(asteroid, 0.0, Vector2(120, -40)),
			_entry(asteroid, 0.3, Vector2(280, -50)),
			_entry(asteroid, 0.3, Vector2(400, -30)),
			_entry(scout, 0.8, Vector2(200, -40), 2, Vector2(90, 0)),
		]),
		_wave("Glacier Wall", 0.5, [
			_entry(asteroid, 0.0, Vector2(90, -40), 2, Vector2(30, 25)),
			_entry(asteroid, 0.2, Vector2(390, -40), 2, Vector2(-30, 25)),
			_entry(strafer, 0.7, Vector2(240, -40)),
		]),
		_wave("Deep Freeze", 0.5, [
			_entry(drone, 0.0, Vector2(240, -40)),
			_entry(asteroid, 0.4, Vector2(140, -50)),
			_entry(asteroid, 0.4, Vector2(340, -50)),
			_entry(scout, 0.8, Vector2(240, -70), 3, Vector2(70, 0)),
		]),
		_wave("Avalanche", 0.4, [
			_entry(asteroid, 0.0, Vector2(100, -40), 4, Vector2(95, 15)),
			_entry(asteroid, 0.6, Vector2(60, -60), 2, Vector2(60, 20)),
			_entry(strafer, 0.9, Vector2(200, -40), 2, Vector2(90, 0)),
		]),
		_wave("Whiteout", 0.4, [
			_entry(asteroid, 0.0, Vector2(80, -40), 3, Vector2(120, 10)),
			_entry(drone, 0.5, Vector2(240, -50)),
			_entry(asteroid, 0.5, Vector2(200, -70), 3, Vector2(80, 20)),
			_entry(scout, 1.0, Vector2(240, -40), 4, Vector2(60, 0)),
		]),
	]
	return m


func _mission_06(scout: EnemyStats, strafer: EnemyStats, asteroid: EnemyStats, drone: EnemyStats, boss_elite: EnemyStats) -> MissionData:
	var m := MissionData.new()
	m.mission_id = &"mission_06"
	m.title = "Event Horizon"
	m.subtitle = "Escape the pull of the void."
	m.scroll_speed = 60.0
	m.background_tint = Color(0.2, 0.06, 0.35)
	m.boss = boss_elite
	m.boss_intro_delay = 2.0
	m.waves = [
		_wave("Accretion Disk", 0.7, [
			_entry(strafer, 0.0, Vector2(120, -40), 2, Vector2(80, 0)),
			_entry(drone, 0.4, Vector2(320, -40)),
			_entry(scout, 0.6, Vector2(200, -40), 3, Vector2(55, 0)),
		]),
		_wave("Tidal Forces", 0.5, [
			_entry(strafer, 0.0, Vector2(80, -40), 3, Vector2(0, 35)),
			_entry(strafer, 0.2, Vector2(400, -40), 3, Vector2(0, 35)),
			_entry(drone, 0.8, Vector2(240, -40), 2, Vector2(100, 0)),
		]),
		_wave("Photon Sphere", 0.5, [
			_entry(drone, 0.0, Vector2(180, -40)),
			_entry(drone, 0.3, Vector2(300, -40)),
			_entry(strafer, 0.6, Vector2(240, -60), 2, Vector2(90, 0)),
			_entry(scout, 0.9, Vector2(100, -40), 5, Vector2(60, 8)),
			_entry(asteroid, 0.4, Vector2(240, -30), 2, Vector2(150, 0)),
		]),
	]
	return m


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (%s)" % [path, err])
	else:
		print("Saved ", path)
