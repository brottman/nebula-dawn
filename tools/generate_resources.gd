extends SceneTree
## Headless generator: 5 thematic campaign stages with unique gimmicks.
## Run: godot --headless --path . --script res://tools/generate_resources.gd


func _init() -> void:
	_ensure_dirs()
	var scout := _enemy(&"scout", "Interceptor", 2.0, 150.0, 100, 0.0, Color(1.0, 0.45, 0.45), Vector2(26, 26))
	var strafer := _enemy(&"strafer", "Defense Drone", 3.0, 115.0, 150, 1.35, Color(1.0, 0.7, 0.35), Vector2(30, 24))
	strafer.projectile_speed = 250.0
	var drone := _enemy(&"drone", "Mining Drone", 6.0, 75.0, 200, 1.7, Color(0.7, 0.4, 1.0), Vector2(34, 34))
	drone.projectile_speed = 210.0
	var cruiser := _enemy(&"strafer", "Armored Cruiser", 8.0, 85.0, 280, 1.5, Color(0.85, 0.45, 0.3), Vector2(40, 28))
	cruiser.projectile_speed = 230.0
	var asteroid := _enemy(&"asteroid", "Asteroid", 6.0, 85.0, 60, 0.0, Color(0.55, 0.5, 0.48), Vector2(40, 40))
	asteroid.is_hazard = true
	asteroid.contact_damage = 1
	var bio := _enemy(&"drone", "Bio-Ship", 5.0, 90.0, 220, 1.5, Color(0.55, 1.0, 0.75), Vector2(32, 32))
	bio.projectile_speed = 200.0
	var stealth := _enemy(&"scout", "Stealth Craft", 3.0, 170.0, 180, 0.0, Color(0.45, 0.35, 0.7), Vector2(24, 24))
	var repair := _enemy(&"drone", "Repair Drone", 4.0, 100.0, 160, 1.6, Color(0.4, 0.95, 0.7), Vector2(28, 28))
	var turret := _enemy(&"strafer", "Heavy Turret", 7.0, 40.0, 240, 1.1, Color(1.0, 0.4, 0.5), Vector2(36, 30))
	turret.projectile_speed = 280.0
	var ace := _enemy(&"strafer", "Ace Fighter", 5.0, 160.0, 300, 1.0, Color(1.0, 0.85, 0.4), Vector2(28, 26))
	ace.projectile_speed = 300.0

	var mid1 := _mid_boss("Heavy Transport", 36.0, 70.0, 1400, 1.25, Color(0.55, 0.8, 1.0), Vector2(64, 48), 240.0)
	var mid2 := _mid_boss("Seismic Drill", 40.0, 55.0, 1600, 1.3, Color(0.8, 0.6, 0.4), Vector2(66, 52), 230.0)
	var mid3 := _mid_boss("Quantum Stalker", 42.0, 90.0, 1800, 1.1, Color(0.7, 0.4, 1.0), Vector2(56, 48), 260.0)
	var mid4 := _mid_boss("Core Overseer", 46.0, 60.0, 1900, 1.15, Color(0.45, 1.0, 0.75), Vector2(58, 58), 250.0)
	var mid5 := _mid_boss("Twin Ace Lead", 38.0, 100.0, 1700, 0.95, Color(1.0, 0.7, 0.3), Vector2(50, 44), 290.0)

	var boss1 := _boss("Orbital Defense Platform", 95.0, 50.0, 5500, 1.1, Color(0.4, 0.75, 1.0), Vector2(96, 72), 260.0)
	var boss2 := _boss("Megalith Dreadnought", 110.0, 45.0, 6500, 1.05, Color(0.75, 0.55, 0.4), Vector2(110, 78), 250.0)
	var boss3 := _boss("Celestial Leviathan", 120.0, 55.0, 7500, 1.0, Color(0.85, 0.45, 1.0), Vector2(100, 80), 270.0)
	var boss4 := _boss("Fabrication Matrix", 130.0, 50.0, 8000, 0.95, Color(0.5, 1.0, 0.7), Vector2(98, 76), 280.0)
	var boss5 := _boss("Omega Engine", 160.0, 65.0, 10000, 0.85, Color(1.0, 0.35, 0.55), Vector2(108, 84), 310.0)

	_save(scout, "res://resources/enemies/scout.tres")
	_save(strafer, "res://resources/enemies/strafer.tres")
	_save(drone, "res://resources/enemies/drone.tres")
	_save(asteroid, "res://resources/enemies/asteroid.tres")
	_save(boss1, "res://resources/enemies/boss.tres")
	_save(boss5, "res://resources/enemies/boss_elite.tres")
	_save(mid1, "res://resources/enemies/mid_boss.tres")

	_save(_mission_01(scout, strafer, mid1, boss1), "res://resources/missions/mission_01_planetary_ascent.tres")
	_save(_mission_02(scout, strafer, asteroid, drone, cruiser, mid2, boss2), "res://resources/missions/mission_02_asteroid_belt.tres")
	_save(_mission_03(scout, stealth, bio, mid3, boss3), "res://resources/missions/mission_03_nebula_anomaly.tres")
	_save(_mission_04(scout, repair, turret, mid4, boss4), "res://resources/missions/mission_04_cybernetic_hive.tres")
	_save(_mission_05(scout, ace, drone, mid5, boss5), "res://resources/missions/mission_05_flagship_core.tres")

	print("Nebula Dawn: 5-stage campaign generated.")
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


func _boss(display: String, hp: float, speed: float, score: int, fire: float, color: Color, size: Vector2, proj: float) -> EnemyStats:
	var e := _enemy(&"boss", display, hp, speed, score, fire, color, size)
	e.is_boss = true
	e.projectile_speed = proj
	e.contact_damage = 2
	return e


func _mid_boss(display: String, hp: float, speed: float, score: int, fire: float, color: Color, size: Vector2, proj: float) -> EnemyStats:
	var e := _boss(display, hp, speed, score, fire, color, size, proj)
	e.is_mid_boss = true
	e.contact_damage = 1
	return e


func _entry(enemy: EnemyStats, delay: float, pos: Vector2, count: int = 1, spacing: Vector2 = Vector2(48, 0), formation: String = "") -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = enemy
	s.delay = delay
	s.position = pos
	s.count = count
	s.spacing = spacing
	s.formation_id = formation
	return s


func _wave(label: String, start: float, entries: Array[SpawnEntry], clear := true, max_clear: float = 8.0) -> WaveDef:
	var w := WaveDef.new()
	w.label = label
	w.start_delay = start
	w.entries = entries
	w.clear_required = clear
	w.max_clear_time = max_clear
	return w


func _mission_base(id: StringName, title: String, subtitle: String, scroll: float, tint: Color, boss: EnemyStats, gimmick: StringName, stage: int, intro: float = 1.8) -> MissionData:
	var m := MissionData.new()
	m.mission_id = id
	m.title = title
	m.subtitle = subtitle
	m.sector = 1
	m.stage = stage
	m.scroll_speed = scroll
	m.background_tint = tint
	m.win_on_waves_cleared = false
	m.boss = boss
	m.boss_intro_delay = intro
	m.gimmick_id = gimmick
	return m


# Stage 1 — Planetary Ascent: formations + chain reactions
func _mission_01(scout: EnemyStats, strafer: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_01", "Planetary Ascent", "Break low orbit over the metropolis.", 38.0, Color(0.2, 0.35, 0.65), boss, &"formations", 1, 1.5)
	m.waves = [
		_wave("Act 1 — Opener", 0.7, [
			_entry(scout, 0.0, Vector2(240, -40), 5, Vector2(45, 18), "v1"),
			_entry(scout, 1.2, Vector2(120, -40), 4, Vector2(55, 0), "line1"),
			_entry(scout, 1.0, Vector2(100, -40), 3, Vector2(70, 12), "sine1"),
			_entry(scout, 0.3, Vector2(380, -40), 3, Vector2(-70, 12), "sine1b"),
		], true, 8.0),
		_wave("Act 2 — Escalation", 1.0, [
			_entry(strafer, 0.0, Vector2(90, -40)),
			_entry(strafer, 0.4, Vector2(390, -40)),
			_entry(scout, 0.8, Vector2(200, -40), 5, Vector2(40, 14), "v2"),
			_entry(strafer, 1.0, Vector2(160, -40), 2, Vector2(100, 0)),
			_entry(scout, 0.9, Vector2(80, -40), 4, Vector2(80, 0), "line2"),
			_entry(scout, 0.8, Vector2(140, -40), 3, Vector2(50, 20), "sweep1"),
			_entry(scout, 0.2, Vector2(340, -40), 3, Vector2(-50, 20), "sweep1b"),
		], true, 8.0),
		_wave("Act 3 — Mid-Boss", 2.0, [_entry(mid, 0.0, Vector2(240, -60))], true, 0.0),
		_wave("Act 4 — Climax", 2.4, [
			_entry(scout, 0.0, Vector2(80, -40), 5, Vector2(50, 10), "finale_v"),
			_entry(strafer, 0.6, Vector2(100, -40), 2, Vector2(0, 40)),
			_entry(strafer, 0.0, Vector2(380, -40), 2, Vector2(0, 40)),
			_entry(scout, 0.9, Vector2(240, -50), 5, Vector2(45, 0), "finale_line"),
			_entry(strafer, 0.8, Vector2(200, -40), 2, Vector2(90, 0)),
			_entry(scout, 0.7, Vector2(120, -40), 4, Vector2(70, 12), "finale_s"),
		], true, 12.0),
	]
	return m


# Stage 2 — Asteroid Belt: splitting rocks that block bullets
func _mission_02(scout: EnemyStats, strafer: EnemyStats, asteroid: EnemyStats, drone: EnemyStats, cruiser: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_02", "The Asteroid Belt", "Use the rocks — or be crushed by them.", 48.0, Color(0.32, 0.22, 0.14), boss, &"asteroids", 2, 1.6)
	m.waves = [
		_wave("Act 1 — Opener", 0.7, [
			_entry(asteroid, 0.0, Vector2(140, -40)),
			_entry(asteroid, 0.5, Vector2(320, -50)),
			_entry(scout, 0.8, Vector2(220, -40), 2, Vector2(80, 0)),
			_entry(asteroid, 0.9, Vector2(240, -40)),
			_entry(scout, 0.8, Vector2(160, -40), 3, Vector2(70, 0)),
		], true, 8.0),
		_wave("Act 2 — Escalation", 1.0, [
			_entry(asteroid, 0.0, Vector2(100, -40), 2, Vector2(140, 20)),
			_entry(strafer, 0.5, Vector2(90, -40), 2, Vector2(0, 40)),
			_entry(strafer, 0.2, Vector2(390, -40), 2, Vector2(0, 40)),
			_entry(drone, 0.9, Vector2(240, -40)),
			_entry(cruiser, 0.8, Vector2(200, -40)),
			_entry(asteroid, 0.6, Vector2(80, -40)),
			_entry(asteroid, 0.3, Vector2(400, -40)),
			_entry(scout, 0.7, Vector2(180, -40), 3, Vector2(60, 0)),
		], true, 8.0),
		_wave("Act 3 — Mid-Boss", 2.0, [_entry(mid, 0.0, Vector2(240, -60))], true, 0.0),
		_wave("Act 4 — Climax", 2.5, [
			_entry(asteroid, 0.0, Vector2(90, -40), 3, Vector2(120, 10)),
			_entry(cruiser, 0.5, Vector2(160, -40)),
			_entry(cruiser, 0.3, Vector2(320, -40)),
			_entry(drone, 0.7, Vector2(240, -40)),
			_entry(asteroid, 0.6, Vector2(60, -50), 2, Vector2(80, 25)),
			_entry(strafer, 0.5, Vector2(100, -40), 2, Vector2(0, 35)),
			_entry(strafer, 0.0, Vector2(380, -40), 2, Vector2(0, 35)),
			_entry(asteroid, 0.8, Vector2(240, -40), 2, Vector2(130, 0)),
			_entry(scout, 0.6, Vector2(140, -40), 4, Vector2(55, 0)),
		], true, 12.0),
	]
	return m


# Stage 3 — Nebula Anomaly: fog + plasma fields
func _mission_03(scout: EnemyStats, stealth: EnemyStats, bio: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_03", "Nebula Anomaly", "Trust the glow — not your eyes.", 52.0, Color(0.4, 0.12, 0.4), boss, &"nebula", 3, 1.8)
	m.waves = [
		_wave("Act 1 — Opener", 0.7, [
			_entry(stealth, 0.0, Vector2(200, -40), 3, Vector2(55, 0)),
			_entry(scout, 0.9, Vector2(120, -40), 3, Vector2(60, 12)),
			_entry(bio, 1.0, Vector2(280, -40)),
			_entry(stealth, 0.8, Vector2(160, -40), 3, Vector2(70, 0)),
		], true, 8.0),
		_wave("Act 2 — Escalation", 1.0, [
			_entry(bio, 0.0, Vector2(180, -40)),
			_entry(bio, 0.4, Vector2(300, -40)),
			_entry(stealth, 0.8, Vector2(100, -40), 4, Vector2(50, 10)),
			_entry(bio, 0.9, Vector2(240, -50)),
			_entry(scout, 0.6, Vector2(140, -40), 3, Vector2(80, 0)),
			_entry(stealth, 0.8, Vector2(80, -40), 3, Vector2(0, 30)),
			_entry(stealth, 0.2, Vector2(400, -40), 3, Vector2(0, 30)),
		], true, 8.0),
		_wave("Act 3 — Mid-Boss", 2.0, [_entry(mid, 0.0, Vector2(240, -60))], true, 0.0),
		_wave("Act 4 — Climax", 2.5, [
			_entry(bio, 0.0, Vector2(160, -40)),
			_entry(bio, 0.3, Vector2(320, -40)),
			_entry(stealth, 0.6, Vector2(100, -40), 5, Vector2(55, 8)),
			_entry(bio, 0.8, Vector2(240, -40), 2, Vector2(90, 0)),
			_entry(scout, 0.6, Vector2(140, -40), 4, Vector2(65, 0)),
			_entry(stealth, 0.7, Vector2(90, -40), 2, Vector2(0, 40)),
			_entry(stealth, 0.0, Vector2(390, -40), 2, Vector2(0, 40)),
			_entry(bio, 0.9, Vector2(220, -40)),
		], true, 12.0),
	]
	return m


# Stage 4 — Cybernetic Hive: barriers + terminals
func _mission_04(scout: EnemyStats, repair: EnemyStats, turret: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_04", "Cybernetic Hive", "Shoot the terminals. Survive the fences.", 58.0, Color(0.15, 0.35, 0.28), boss, &"hive", 4, 1.7)
	m.waves = [
		_wave("Act 1 — Opener", 0.6, [
			_entry(repair, 0.0, Vector2(160, -40)),
			_entry(repair, 0.5, Vector2(320, -40)),
			_entry(scout, 0.8, Vector2(240, -40), 3, Vector2(60, 0)),
			_entry(turret, 1.0, Vector2(240, -50)),
		], true, 8.0),
		_wave("Act 2 — Escalation", 1.0, [
			_entry(turret, 0.0, Vector2(120, -40)),
			_entry(turret, 0.4, Vector2(360, -40)),
			_entry(repair, 0.8, Vector2(200, -40), 2, Vector2(90, 0)),
			_entry(scout, 0.7, Vector2(140, -40), 4, Vector2(55, 0)),
			_entry(turret, 0.9, Vector2(240, -40)),
			_entry(repair, 0.6, Vector2(100, -40), 2, Vector2(0, 35)),
			_entry(repair, 0.2, Vector2(380, -40), 2, Vector2(0, 35)),
		], true, 8.0),
		_wave("Act 3 — Mid-Boss", 2.0, [_entry(mid, 0.0, Vector2(240, -60))], true, 0.0),
		_wave("Act 4 — Climax", 2.4, [
			_entry(turret, 0.0, Vector2(100, -40)),
			_entry(turret, 0.3, Vector2(380, -40)),
			_entry(repair, 0.6, Vector2(200, -40), 3, Vector2(50, 0)),
			_entry(scout, 0.7, Vector2(120, -40), 5, Vector2(50, 8)),
			_entry(turret, 0.8, Vector2(240, -50)),
			_entry(repair, 0.5, Vector2(90, -40), 2, Vector2(0, 40)),
			_entry(repair, 0.0, Vector2(390, -40), 2, Vector2(0, 40)),
			_entry(turret, 0.9, Vector2(180, -40)),
			_entry(turret, 0.3, Vector2(300, -40)),
		], true, 12.0),
	]
	return m


# Stage 5 — Flagship Core: singularities + overdrive
func _mission_05(scout: EnemyStats, ace: EnemyStats, drone: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_05", "Flagship Core", "Graze the void. Break the Omega Engine.", 62.0, Color(0.22, 0.06, 0.28), boss, &"gravity", 5, 2.0)
	m.waves = [
		_wave("Act 1 — Opener", 0.7, [
			_entry(ace, 0.0, Vector2(140, -40)),
			_entry(ace, 0.5, Vector2(340, -40)),
			_entry(scout, 0.8, Vector2(220, -40), 3, Vector2(55, 0)),
			_entry(ace, 1.0, Vector2(240, -40), 2, Vector2(100, 0)),
		], true, 8.0),
		_wave("Act 2 — Escalation", 1.0, [
			_entry(ace, 0.0, Vector2(80, -40), 2, Vector2(0, 40)),
			_entry(ace, 0.3, Vector2(400, -40), 2, Vector2(0, 40)),
			_entry(drone, 0.9, Vector2(240, -40), 2, Vector2(100, 0)),
			_entry(scout, 0.6, Vector2(160, -40), 4, Vector2(55, 0)),
			_entry(ace, 0.8, Vector2(200, -40), 2, Vector2(90, 0)),
			_entry(drone, 0.7, Vector2(180, -50)),
			_entry(drone, 0.3, Vector2(300, -50)),
		], true, 8.0),
		_wave("Act 3 — Mid-Boss", 2.0, [
			_entry(mid, 0.0, Vector2(180, -60)),
			_entry(mid, 0.4, Vector2(300, -60)),
		], true, 0.0),
		_wave("Act 4 — Climax", 2.5, [
			_entry(ace, 0.0, Vector2(90, -40), 3, Vector2(0, 35)),
			_entry(ace, 0.0, Vector2(390, -40), 3, Vector2(0, 35)),
			_entry(drone, 0.8, Vector2(200, -40), 2, Vector2(100, 0)),
			_entry(scout, 0.6, Vector2(120, -40), 5, Vector2(50, 8)),
			_entry(ace, 0.7, Vector2(240, -40), 2, Vector2(90, 0)),
			_entry(drone, 0.8, Vector2(240, -50)),
			_entry(ace, 0.6, Vector2(140, -40)),
			_entry(ace, 0.3, Vector2(340, -40)),
			_entry(scout, 0.7, Vector2(100, -40), 5, Vector2(55, 0)),
		], true, 12.0),
	]
	return m


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (%s)" % [path, err])
	else:
		print("Saved ", path)
