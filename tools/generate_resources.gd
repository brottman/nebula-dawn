extends SceneTree
## Headless generator: Sector 1 + Sector 2 campaign stages with unique gimmicks.
## Run: godot --headless --path . --script res://tools/generate_resources.gd


func _init() -> void:
	_ensure_dirs()
	# Softer Sector 1 curve: fodder dies fast, shooters fire slower / softer.
	var scout := _enemy(&"scout", "Interceptor", 1.0, 130.0, 100, 0.0, Color(1.0, 0.45, 0.45), Vector2(40, 40))
	var strafer := _enemy(&"strafer", "Defense Drone", 2.0, 95.0, 150, 1.8, Color(1.0, 0.7, 0.35), Vector2(46, 38))
	strafer.projectile_speed = 200.0
	strafer.fire_pattern = &"side"
	var drone := _enemy(&"drone", "Mining Drone", 3.0, 65.0, 200, 2.2, Color(0.7, 0.4, 1.0), Vector2(50, 50))
	drone.projectile_speed = 170.0
	drone.fire_pattern = &"burst"
	var cruiser := _enemy(&"strafer", "Armored Cruiser", 4.0, 72.0, 280, 2.0, Color(0.85, 0.45, 0.3), Vector2(58, 42))
	cruiser.projectile_speed = 185.0
	cruiser.fire_pattern = &"spread"
	var asteroid := _enemy(&"asteroid", "Asteroid", 3.0, 70.0, 60, 0.0, Color(0.55, 0.5, 0.48), Vector2(56, 56))
	asteroid.is_hazard = true
	asteroid.contact_damage = 1
	var bio := _enemy(&"drone", "Bio-Ship", 3.0, 78.0, 220, 2.2, Color(0.55, 1.0, 0.75), Vector2(48, 48))
	bio.projectile_speed = 165.0
	bio.fire_pattern = &"aimed"
	var stealth := _enemy(&"scout", "Stealth Craft", 1.0, 150.0, 180, 0.0, Color(0.45, 0.35, 0.7), Vector2(38, 38))
	var repair := _enemy(&"drone", "Repair Drone", 2.0, 88.0, 160, 2.1, Color(0.4, 0.95, 0.7), Vector2(44, 44))
	repair.fire_pattern = &"aimed"
	var turret := _enemy(&"strafer", "Heavy Turret", 4.0, 32.0, 240, 1.55, Color(1.0, 0.4, 0.5), Vector2(52, 44))
	turret.projectile_speed = 220.0
	turret.fire_pattern = &"aimed"
	var ace := _enemy(&"strafer", "Ace Fighter", 3.0, 135.0, 300, 1.45, Color(1.0, 0.85, 0.4), Vector2(44, 40))
	ace.projectile_speed = 230.0
	ace.fire_pattern = &"aimed"
	# Sector 2 denser fodder.
	var mirror_drone := _enemy(&"drone", "Prism Drone", 3.0, 80.0, 240, 1.7, Color(0.55, 0.85, 1.0), Vector2(48, 46))
	mirror_drone.projectile_speed = 200.0
	mirror_drone.fire_pattern = &"ring"
	var ion_raider := _enemy(&"strafer", "Ion Raider", 3.0, 110.0, 260, 1.5, Color(0.4, 0.9, 1.0), Vector2(46, 40))
	ion_raider.projectile_speed = 240.0
	ion_raider.fire_pattern = &"aimed"
	var phantom := _enemy(&"scout", "Phantom Wisp", 2.0, 145.0, 200, 1.9, Color(0.35, 0.55, 0.95), Vector2(36, 36))
	phantom.fire_pattern = &"aimed"
	var scrap_bot := _enemy(&"drone", "Scrap Bot", 4.0, 70.0, 220, 2.0, Color(0.9, 0.55, 0.3), Vector2(50, 48))
	scrap_bot.fire_pattern = &"cross"
	var dawn_guard := _enemy(&"strafer", "Dawn Guard", 4.0, 100.0, 320, 1.35, Color(1.0, 0.7, 0.35), Vector2(48, 42))
	dawn_guard.projectile_speed = 245.0
	dawn_guard.fire_pattern = &"aimed"

	var mid1 := _mid_boss("Heavy Transport", 36.0, 60.0, 1600, 1.55, Color(0.55, 0.8, 1.0), Vector2(84, 64), 190.0)
	var mid2 := _mid_boss("Seismic Drill", 40.0, 48.0, 1800, 1.6, Color(0.8, 0.6, 0.4), Vector2(88, 70), 185.0)
	var mid3 := _mid_boss("Quantum Stalker", 42.0, 78.0, 2000, 1.4, Color(0.7, 0.4, 1.0), Vector2(76, 66), 200.0)
	var mid4 := _mid_boss("Core Overseer", 44.0, 52.0, 2100, 1.45, Color(0.45, 1.0, 0.75), Vector2(78, 78), 195.0)
	var mid5 := _mid_boss("Twin Ace Lead", 38.0, 85.0, 1900, 1.25, Color(1.0, 0.7, 0.3), Vector2(70, 60), 220.0)
	var mid6 := _mid_boss("Prism Warden", 48.0, 58.0, 2300, 1.35, Color(0.5, 0.9, 1.0), Vector2(80, 70), 210.0)
	var mid7 := _mid_boss("Storm Coil", 50.0, 55.0, 2400, 1.3, Color(0.4, 0.85, 1.0), Vector2(82, 72), 220.0)
	var mid8 := _mid_boss("Echo Revenant", 52.0, 70.0, 2500, 1.25, Color(0.4, 0.55, 1.0), Vector2(78, 68), 215.0)
	var mid9 := _mid_boss("Belt Tyrant", 54.0, 50.0, 2600, 1.3, Color(0.95, 0.55, 0.3), Vector2(86, 74), 205.0)
	var mid10 := _mid_boss("Solar Herald", 56.0, 62.0, 2800, 1.2, Color(1.0, 0.65, 0.3), Vector2(84, 72), 230.0)

	var boss1 := _boss("Orbital Defense Platform", 100.0, 42.0, 6500, 1.4, Color(0.4, 0.75, 1.0), Vector2(120, 92), 200.0)
	var boss2 := _boss("Megalith Dreadnought", 115.0, 38.0, 7500, 1.35, Color(0.75, 0.55, 0.4), Vector2(136, 98), 195.0)
	var boss3 := _boss("Celestial Leviathan", 125.0, 46.0, 8500, 1.3, Color(0.85, 0.45, 1.0), Vector2(128, 100), 210.0)
	var boss4 := _boss("Fabrication Matrix", 135.0, 42.0, 9000, 1.25, Color(0.5, 1.0, 0.7), Vector2(124, 96), 215.0)
	var boss5 := _boss("Omega Engine", 160.0, 55.0, 12000, 1.15, Color(1.0, 0.35, 0.55), Vector2(136, 108), 235.0)
	var boss6 := _boss("Kaleidoscope Array", 150.0, 48.0, 10000, 1.2, Color(0.45, 0.9, 1.0), Vector2(128, 96), 220.0)
	var boss7 := _boss("Tempest Dynamo", 160.0, 50.0, 11000, 1.15, Color(0.35, 0.8, 1.0), Vector2(130, 100), 230.0)
	var boss8 := _boss("Null Choir", 170.0, 52.0, 12000, 1.1, Color(0.4, 0.5, 1.0), Vector2(132, 102), 225.0)
	var boss9 := _boss("Junkyard Colossus", 180.0, 44.0, 12500, 1.15, Color(0.9, 0.5, 0.28), Vector2(140, 108), 215.0)
	var boss10 := _boss("Dawn Gate Core", 200.0, 58.0, 15000, 1.05, Color(1.0, 0.55, 0.25), Vector2(144, 112), 245.0)

	# Boss archetypes drive BossPatterns (scripts/enemies/boss_patterns.gd).
	boss1.boss_archetype = &"orbital"
	boss2.boss_archetype = &"megalith"
	boss3.boss_archetype = &"leviathan"
	boss4.boss_archetype = &"fabrication"
	boss5.boss_archetype = &"omega"
	boss6.boss_archetype = &"kaleidoscope"
	boss7.boss_archetype = &"tempest"
	boss8.boss_archetype = &"choir"
	boss9.boss_archetype = &"junkyard"
	boss10.boss_archetype = &"dawn"

	# Mid-boss archetypes.
	mid1.boss_archetype = &"transport"
	mid2.boss_archetype = &"drill"
	mid3.boss_archetype = &"stalker"
	mid4.boss_archetype = &"overseer"
	mid5.boss_archetype = &"ace"
	mid6.boss_archetype = &"prism"
	mid7.boss_archetype = &"coil"
	mid8.boss_archetype = &"echo"
	mid9.boss_archetype = &"tyrant"
	mid10.boss_archetype = &"herald"

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
	_save(_mission_06(scout, mirror_drone, ace, mid6, boss6), "res://resources/missions/mission_06_mirror_field.tres")
	_save(_mission_07(scout, ion_raider, turret, mid7, boss7), "res://resources/missions/mission_07_ion_storm.tres")
	_save(_mission_08(phantom, stealth, bio, mid8, boss8), "res://resources/missions/mission_08_phantom_wake.tres")
	_save(_mission_09(scrap_bot, cruiser, drone, mid9, boss9), "res://resources/missions/mission_09_scrap_gauntlet.tres")
	_save(_mission_10(dawn_guard, ace, ion_raider, mid10, boss10), "res://resources/missions/mission_10_dawn_gate.tres")

	print("Nebula Dawn: 10-stage campaign (Sector 1+2) generated.")
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


func _entry(
	enemy: EnemyStats,
	delay: float,
	pos: Vector2,
	count: int = 1,
	pat: StringName = &"line",
	spread: float = 56.0,
	formation: String = "",
	spacing: Vector2 = Vector2(56, 0)
) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = enemy
	s.delay = delay
	s.position = pos
	s.count = count
	s.pattern = pat
	s.pattern_spread = spread
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


func _mission_base(id: StringName, title: String, subtitle: String, scroll: float, tint: Color, boss: EnemyStats, gimmick: StringName, stage: int, intro: float = 1.8, sector: int = 1, terrain: StringName = &"city") -> MissionData:
	var m := MissionData.new()
	m.mission_id = id
	m.title = title
	m.subtitle = subtitle
	m.sector = sector
	m.stage = stage
	m.scroll_speed = scroll
	m.background_tint = tint
	m.win_on_waves_cleared = false
	m.boss = boss
	m.boss_intro_delay = intro
	m.gimmick_id = gimmick
	m.terrain_id = terrain
	return m


# Stage 1 — Planetary Ascent: formations + chain reactions
func _mission_01(scout: EnemyStats, strafer: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_01", "Planetary Ascent", "Break low orbit over the metropolis.", 38.0, Color(0.2, 0.35, 0.65), boss, &"formations", 1, 2.2, 1, &"city")
	m.waves = [
		_wave("Act 1 — Opener", 1.0, [
			_entry(scout, 0.0, Vector2(240, -50), 5, &"v", 54.0, "v1"),
			_entry(scout, 1.6, Vector2(240, -50), 5, &"line", 58.0, "line1"),
			_entry(scout, 1.5, Vector2(240, -55), 5, &"arc", 50.0, "arc1"),
			_entry(scout, 1.4, Vector2(240, -50), 5, &"wave", 52.0, "wave1"),
			_entry(scout, 1.5, Vector2(240, -55), 5, &"inv_v", 54.0, "inv0"),
		], true, 14.0),
		_wave("Act 1 — Sweep", 1.4, [
			_entry(scout, 0.0, Vector2(120, -50), 4, &"column", 40.0, "col_l"),
			_entry(scout, 0.3, Vector2(360, -50), 4, &"column", 40.0, "col_r"),
			_entry(scout, 1.4, Vector2(240, -55), 6, &"diamond", 48.0, "dia0"),
			_entry(scout, 1.2, Vector2(240, -55), 7, &"circle", 52.0, "circ0"),
			_entry(scout, 1.5, Vector2(240, -50), 5, &"cross", 46.0, "cross0"),
			_entry(scout, 1.4, Vector2(240, -55), 6, &"arc", 50.0, "arc0b"),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.6, [
			_entry(strafer, 0.0, Vector2(100, -50), 3, &"column", 42.0),
			_entry(strafer, 0.3, Vector2(380, -50), 3, &"column", 42.0),
			_entry(scout, 1.2, Vector2(240, -55), 5, &"diamond", 48.0, "dia1"),
			_entry(scout, 1.3, Vector2(240, -55), 9, &"star", 54.0, "star1"),
			_entry(scout, 1.4, Vector2(240, -50), 5, &"inv_v", 54.0, "inv1"),
			_entry(strafer, 1.2, Vector2(240, -50), 4, &"line", 70.0),
			_entry(scout, 1.3, Vector2(240, -55), 5, &"cross", 46.0, "cross1"),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(strafer, 0.0, Vector2(240, -50), 4, &"wave", 62.0),
			_entry(scout, 1.2, Vector2(240, -55), 7, &"v", 48.0, "v2"),
			_entry(strafer, 1.0, Vector2(90, -50), 3, &"column", 38.0),
			_entry(strafer, 0.2, Vector2(390, -50), 3, &"column", 38.0),
			_entry(scout, 1.3, Vector2(240, -50), 6, &"box", 50.0, "box1"),
			_entry(scout, 1.4, Vector2(240, -55), 6, &"arc", 52.0, "arc2"),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.4, [_entry(mid, 0.0, Vector2(240, -70))], true, 0.0),
		_wave("Act 4 — Build", 2.2, [
			_entry(scout, 0.0, Vector2(240, -55), 6, &"v", 50.0, "build_v"),
			_entry(strafer, 1.0, Vector2(110, -50), 3, &"column", 40.0),
			_entry(strafer, 0.2, Vector2(370, -50), 3, &"column", 40.0),
			_entry(scout, 1.3, Vector2(240, -50), 5, &"wave", 54.0, "build_w"),
			_entry(scout, 1.4, Vector2(240, -55), 6, &"diamond", 48.0, "build_d"),
			_entry(strafer, 1.2, Vector2(240, -50), 4, &"line", 68.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.6, [
			_entry(scout, 0.0, Vector2(240, -55), 7, &"v", 48.0, "finale_v"),
			_entry(strafer, 0.9, Vector2(120, -50), 4, &"column", 38.0),
			_entry(strafer, 0.2, Vector2(360, -50), 4, &"column", 38.0),
			_entry(scout, 1.2, Vector2(240, -55), 6, &"box", 50.0, "finale_box"),
			_entry(scout, 1.3, Vector2(240, -55), 10, &"chevron", 50.0, "finale_chev"),
			_entry(scout, 1.3, Vector2(240, -50), 7, &"arc", 50.0, "finale_arc"),
			_entry(strafer, 1.1, Vector2(240, -50), 4, &"wave", 60.0),
			_entry(scout, 1.3, Vector2(240, -55), 6, &"cross", 46.0, "finale_x"),
			_entry(scout, 1.2, Vector2(240, -50), 5, &"inv_v", 54.0, "finale_inv"),
		], true, 20.0),
	]
	return m


# Stage 2 — Asteroid Belt: splitting rocks that block bullets
func _mission_02(scout: EnemyStats, strafer: EnemyStats, asteroid: EnemyStats, drone: EnemyStats, cruiser: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_02", "The Asteroid Belt", "Use the rocks — or be crushed by them.", 48.0, Color(0.32, 0.22, 0.14), boss, &"asteroids", 2, 2.2, 1, &"mines")
	m.waves = [
		_wave("Act 1 — Opener", 1.0, [
			_entry(asteroid, 0.0, Vector2(240, -55), 3, &"arc", 70.0),
			_entry(scout, 1.2, Vector2(240, -50), 4, &"v", 56.0),
			_entry(asteroid, 1.2, Vector2(240, -60), 3, &"line", 100.0),
			_entry(scout, 1.1, Vector2(240, -50), 5, &"wave", 52.0),
			_entry(asteroid, 1.3, Vector2(160, -55), 2, &"line", 140.0),
			_entry(asteroid, 0.4, Vector2(320, -55), 2, &"line", 140.0),
		], true, 14.0),
		_wave("Act 1 — Drift", 1.4, [
			_entry(asteroid, 0.0, Vector2(240, -55), 4, &"diamond", 64.0),
			_entry(scout, 1.2, Vector2(240, -50), 5, &"arc", 50.0),
			_entry(asteroid, 1.3, Vector2(100, -60), 3, &"column", 48.0),
			_entry(asteroid, 0.3, Vector2(380, -60), 3, &"column", 48.0),
			_entry(scout, 1.4, Vector2(240, -50), 5, &"inv_v", 52.0),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.5, [
			_entry(asteroid, 0.0, Vector2(240, -55), 4, &"arc", 62.0),
			_entry(strafer, 0.7, Vector2(90, -50), 2, &"column", 40.0),
			_entry(strafer, 0.8, Vector2(390, -50), 2, &"column", 40.0),
			_entry(drone, 1.5, Vector2(240, -50), 2, &"line", 80.0),
			_entry(cruiser, 1.7, Vector2(240, -55), 1, &"line", 120.0),
			_entry(scout, 1.4, Vector2(240, -50), 4, &"inv_v", 52.0),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(asteroid, 0.0, Vector2(240, -55), 4, &"wave", 58.0),
			_entry(cruiser, 1.2, Vector2(180, -50), 1, &"line", 130.0),
			_entry(drone, 1.4, Vector2(240, -55), 2, &"v", 60.0),
			_entry(strafer, 1.2, Vector2(100, -50), 2, &"column", 38.0),
			_entry(strafer, 0.9, Vector2(380, -50), 2, &"column", 38.0),
			_entry(scout, 1.5, Vector2(240, -50), 4, &"cross", 48.0),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.4, [_entry(mid, 0.0, Vector2(240, -70))], true, 0.0),
		_wave("Act 4 — Build", 2.2, [
			_entry(asteroid, 0.0, Vector2(240, -55), 4, &"box", 68.0),
			_entry(drone, 1.2, Vector2(240, -50), 2, &"line", 90.0),
			_entry(cruiser, 1.3, Vector2(200, -55)),
			_entry(cruiser, 0.8, Vector2(280, -55)),
			_entry(scout, 1.4, Vector2(240, -50), 4, &"v", 54.0),
			_entry(asteroid, 1.3, Vector2(120, -60), 3, &"arc", 70.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.6, [
			_entry(asteroid, 0.0, Vector2(240, -55), 4, &"arc", 58.0),
			_entry(cruiser, 1.0, Vector2(240, -50), 1, &"line", 140.0),
			_entry(drone, 1.2, Vector2(240, -55), 3, &"v", 58.0),
			_entry(strafer, 1.1, Vector2(100, -50), 3, &"column", 36.0),
			_entry(strafer, 0.6, Vector2(380, -50), 3, &"column", 36.0),
			_entry(asteroid, 1.4, Vector2(240, -60), 4, &"box", 66.0),
			_entry(scout, 1.3, Vector2(240, -50), 4, &"cross", 48.0),
			_entry(drone, 1.5, Vector2(240, -55), 2, &"wave", 72.0),
		], true, 20.0),
	]
	return m


# Stage 3 — Nebula Anomaly: fog + plasma fields
func _mission_03(scout: EnemyStats, stealth: EnemyStats, bio: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_03", "Nebula Anomaly", "Trust the glow — not your eyes.", 52.0, Color(0.4, 0.12, 0.4), boss, &"nebula", 3, 2.4, 1, &"biolum")
	m.waves = [
		_wave("Act 1 — Opener", 1.0, [
			_entry(stealth, 0.0, Vector2(240, -50), 5, &"wave", 50.0),
			_entry(scout, 1.3, Vector2(240, -55), 5, &"arc", 48.0),
			_entry(bio, 1.3, Vector2(240, -50), 3, &"v", 70.0),
			_entry(stealth, 1.2, Vector2(240, -50), 5, &"inv_v", 52.0),
			_entry(scout, 1.3, Vector2(240, -55), 5, &"line", 56.0),
		], true, 14.0),
		_wave("Act 1 — Drift", 1.4, [
			_entry(stealth, 0.0, Vector2(240, -50), 6, &"diamond", 46.0),
			_entry(bio, 1.2, Vector2(180, -55)),
			_entry(bio, 0.4, Vector2(300, -55)),
			_entry(stealth, 1.3, Vector2(110, -50), 4, &"column", 36.0),
			_entry(stealth, 0.3, Vector2(370, -50), 4, &"column", 36.0),
			_entry(scout, 1.3, Vector2(240, -50), 5, &"cross", 48.0),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.5, [
			_entry(bio, 0.0, Vector2(240, -55), 3, &"line", 90.0),
			_entry(stealth, 1.1, Vector2(240, -50), 6, &"diamond", 46.0),
			_entry(bio, 1.2, Vector2(240, -55), 3, &"arc", 64.0),
			_entry(bio, 1.2, Vector2(240, -55), 7, &"spiral", 58.0),
			_entry(scout, 1.0, Vector2(240, -50), 5, &"cross", 48.0),
			_entry(stealth, 1.1, Vector2(110, -50), 4, &"column", 36.0),
			_entry(stealth, 0.3, Vector2(370, -50), 4, &"column", 36.0),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(bio, 0.0, Vector2(240, -55), 4, &"v", 58.0),
			_entry(stealth, 1.1, Vector2(240, -50), 7, &"wave", 48.0),
			_entry(scout, 1.1, Vector2(240, -55), 5, &"box", 50.0),
			_entry(bio, 1.2, Vector2(200, -50), 2, &"line", 100.0),
			_entry(stealth, 1.1, Vector2(100, -50), 3, &"column", 40.0),
			_entry(stealth, 0.2, Vector2(380, -50), 3, &"column", 40.0),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.4, [_entry(mid, 0.0, Vector2(240, -70))], true, 0.0),
		_wave("Act 4 — Build", 2.2, [
			_entry(stealth, 0.0, Vector2(240, -50), 6, &"arc", 48.0),
			_entry(bio, 1.1, Vector2(240, -55), 3, &"inv_v", 70.0),
			_entry(scout, 1.2, Vector2(240, -50), 5, &"diamond", 50.0),
			_entry(stealth, 1.1, Vector2(120, -50), 4, &"column", 38.0),
			_entry(stealth, 0.3, Vector2(360, -50), 4, &"column", 38.0),
			_entry(bio, 1.2, Vector2(240, -55), 3, &"wave", 72.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.6, [
			_entry(bio, 0.0, Vector2(240, -55), 4, &"v", 58.0),
			_entry(stealth, 0.9, Vector2(240, -50), 7, &"arc", 46.0),
			_entry(bio, 1.1, Vector2(240, -55), 4, &"box", 68.0),
			_entry(scout, 1.0, Vector2(240, -50), 6, &"wave", 52.0),
			_entry(stealth, 1.0, Vector2(100, -50), 4, &"column", 38.0),
			_entry(stealth, 0.2, Vector2(380, -50), 4, &"column", 38.0),
			_entry(bio, 1.2, Vector2(240, -50), 3, &"inv_v", 72.0),
			_entry(stealth, 1.1, Vector2(240, -55), 6, &"cross", 48.0),
		], true, 20.0),
	]
	return m


# Stage 4 — Cybernetic Hive: barriers + terminals
func _mission_04(scout: EnemyStats, repair: EnemyStats, turret: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_04", "Cybernetic Hive", "Shoot the terminals. Survive the fences.", 58.0, Color(0.15, 0.35, 0.28), boss, &"hive", 4, 2.3, 1, &"factory")
	m.waves = [
		_wave("Act 1 — Opener", 1.0, [
			_entry(repair, 0.0, Vector2(240, -50), 3, &"v", 70.0),
			_entry(scout, 1.2, Vector2(240, -55), 5, &"line", 56.0),
			_entry(turret, 1.3, Vector2(240, -55), 3, &"line", 110.0),
			_entry(repair, 1.2, Vector2(240, -50), 4, &"arc", 58.0),
			_entry(scout, 1.3, Vector2(240, -55), 5, &"wave", 52.0),
		], true, 14.0),
		_wave("Act 1 — Sweep", 1.4, [
			_entry(turret, 0.0, Vector2(140, -55)),
			_entry(turret, 0.4, Vector2(340, -55)),
			_entry(repair, 1.1, Vector2(240, -50), 4, &"diamond", 52.0),
			_entry(scout, 1.2, Vector2(240, -55), 5, &"box", 48.0),
			_entry(repair, 1.2, Vector2(100, -50), 3, &"column", 38.0),
			_entry(repair, 0.3, Vector2(380, -50), 3, &"column", 38.0),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.5, [
			_entry(turret, 0.0, Vector2(240, -55), 3, &"arc", 90.0),
			_entry(repair, 1.1, Vector2(240, -50), 4, &"diamond", 52.0),
			_entry(scout, 1.0, Vector2(240, -55), 5, &"box", 48.0),
			_entry(turret, 1.2, Vector2(240, -50), 2, &"line", 140.0),
			_entry(repair, 1.0, Vector2(100, -50), 3, &"column", 38.0),
			_entry(repair, 0.3, Vector2(380, -50), 3, &"column", 38.0),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(turret, 0.0, Vector2(120, -55)),
			_entry(turret, 0.3, Vector2(240, -50)),
			_entry(turret, 0.3, Vector2(360, -55)),
			_entry(repair, 1.1, Vector2(240, -50), 5, &"v", 50.0),
			_entry(scout, 1.1, Vector2(240, -55), 6, &"wave", 48.0),
			_entry(repair, 1.1, Vector2(90, -50), 3, &"column", 40.0),
			_entry(repair, 0.2, Vector2(390, -50), 3, &"column", 40.0),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.4, [_entry(mid, 0.0, Vector2(240, -70))], true, 0.0),
		_wave("Act 4 — Build", 2.2, [
			_entry(turret, 0.0, Vector2(240, -55), 3, &"line", 120.0),
			_entry(repair, 1.0, Vector2(240, -50), 4, &"arc", 56.0),
			_entry(scout, 1.1, Vector2(240, -55), 5, &"inv_v", 54.0),
			_entry(turret, 1.1, Vector2(160, -50)),
			_entry(turret, 0.4, Vector2(320, -50)),
			_entry(repair, 1.2, Vector2(240, -55), 4, &"cross", 52.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.6, [
			_entry(turret, 0.0, Vector2(240, -55), 4, &"cross", 70.0),
			_entry(repair, 0.9, Vector2(240, -50), 5, &"v", 50.0),
			_entry(scout, 1.0, Vector2(240, -55), 7, &"wave", 46.0),
			_entry(turret, 1.1, Vector2(240, -50), 3, &"line", 120.0),
			_entry(repair, 0.9, Vector2(90, -50), 4, &"column", 38.0),
			_entry(repair, 0.2, Vector2(390, -50), 4, &"column", 38.0),
			_entry(scout, 1.1, Vector2(240, -55), 6, &"inv_v", 52.0),
			_entry(turret, 1.1, Vector2(180, -50)),
			_entry(turret, 0.3, Vector2(300, -50)),
		], true, 20.0),
	]
	return m


# Stage 5 — Flagship Core: singularities + overdrive
func _mission_05(scout: EnemyStats, ace: EnemyStats, drone: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_05", "Flagship Core", "Graze the void. Break the Omega Engine.", 62.0, Color(0.22, 0.06, 0.28), boss, &"gravity", 5, 2.6, 1, &"fleet")
	m.waves = [
		_wave("Act 1 — Opener", 1.0, [
			_entry(ace, 0.0, Vector2(240, -50), 3, &"v", 80.0),
			_entry(scout, 1.2, Vector2(240, -55), 5, &"arc", 50.0),
			_entry(ace, 1.3, Vector2(240, -50), 4, &"line", 70.0),
			_entry(scout, 1.2, Vector2(240, -50), 5, &"wave", 52.0),
			_entry(ace, 1.3, Vector2(140, -55)),
			_entry(ace, 0.4, Vector2(340, -55)),
		], true, 14.0),
		_wave("Act 1 — Sweep", 1.4, [
			_entry(ace, 0.0, Vector2(90, -50), 3, &"column", 40.0),
			_entry(ace, 0.3, Vector2(390, -50), 3, &"column", 40.0),
			_entry(scout, 1.2, Vector2(240, -55), 6, &"diamond", 48.0),
			_entry(drone, 1.2, Vector2(240, -50), 3, &"line", 90.0),
			_entry(scout, 1.2, Vector2(240, -55), 5, &"inv_v", 54.0),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.5, [
			_entry(ace, 0.0, Vector2(90, -50), 4, &"column", 38.0),
			_entry(ace, 0.3, Vector2(390, -50), 4, &"column", 38.0),
			_entry(drone, 1.2, Vector2(240, -55), 3, &"diamond", 60.0),
			_entry(scout, 1.0, Vector2(240, -50), 6, &"cross", 46.0),
			_entry(ace, 1.1, Vector2(240, -55), 4, &"inv_v", 58.0),
			_entry(drone, 1.0, Vector2(240, -50), 3, &"arc", 72.0),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(ace, 0.0, Vector2(240, -50), 4, &"wave", 64.0),
			_entry(scout, 1.1, Vector2(240, -55), 7, &"v", 48.0),
			_entry(ace, 1.2, Vector2(240, -55), 6, &"circle", 66.0),
			_entry(drone, 1.1, Vector2(180, -50), 2, &"line", 120.0),
			_entry(drone, 0.4, Vector2(300, -50)),
			_entry(ace, 1.1, Vector2(100, -55), 3, &"column", 38.0),
			_entry(ace, 0.2, Vector2(380, -55), 3, &"column", 38.0),
			_entry(scout, 1.2, Vector2(240, -50), 6, &"box", 50.0),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.5, [
			_entry(mid, 0.0, Vector2(240, -75), 2, &"line", 120.0),
		], true, 0.0),
		_wave("Act 4 — Build", 2.3, [
			_entry(ace, 0.0, Vector2(90, -50), 3, &"column", 40.0),
			_entry(ace, 0.2, Vector2(390, -50), 3, &"column", 40.0),
			_entry(drone, 1.1, Vector2(240, -55), 4, &"v", 58.0),
			_entry(scout, 1.1, Vector2(240, -50), 6, &"arc", 48.0),
			_entry(ace, 1.1, Vector2(240, -55), 4, &"line", 68.0),
			_entry(drone, 1.1, Vector2(240, -50), 3, &"wave", 70.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.7, [
			_entry(ace, 0.0, Vector2(90, -50), 4, &"column", 36.0),
			_entry(ace, 0.0, Vector2(390, -50), 4, &"column", 36.0),
			_entry(drone, 1.0, Vector2(240, -55), 4, &"v", 58.0),
			_entry(scout, 0.9, Vector2(240, -50), 7, &"arc", 44.0),
			_entry(ace, 1.0, Vector2(240, -55), 4, &"box", 64.0),
			_entry(drone, 1.1, Vector2(240, -50), 4, &"wave", 66.0),
			_entry(scout, 1.0, Vector2(240, -55), 6, &"diamond", 48.0),
			_entry(ace, 1.1, Vector2(140, -50)),
			_entry(ace, 0.3, Vector2(340, -50)),
			_entry(scout, 1.1, Vector2(240, -55), 5, &"cross", 50.0),
		], true, 22.0),
	]
	return m


# Stage 6 — Mirror Field: bouncing plates
func _mission_06(scout: EnemyStats, prism: EnemyStats, ace: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_06", "Mirror Field", "Ricochets rewrite the lane map.", 58.0, Color(0.12, 0.28, 0.42), boss, &"mirrors", 1, 2.3, 2, &"mirror")
	m.waves = _sector2_wave_kit(scout, prism, ace, mid)
	return m


# Stage 7 — Ion Storm: lightning columns
func _mission_07(scout: EnemyStats, raider: EnemyStats, turret: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_07", "Ion Storm", "Read the strike lanes — or burn.", 60.0, Color(0.1, 0.22, 0.38), boss, &"ion", 2, 2.3, 2, &"storm")
	m.waves = _sector2_wave_kit(scout, raider, turret, mid)
	return m


# Stage 8 — Phantom Wake: echo volleys
func _mission_08(phantom: EnemyStats, stealth: EnemyStats, bio: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_08", "Phantom Wake", "They shoot where you were.", 62.0, Color(0.14, 0.16, 0.4), boss, &"phantoms", 3, 2.4, 2, &"wake")
	m.waves = _sector2_wave_kit(phantom, stealth, bio, mid)
	return m


# Stage 9 — Scrap Gauntlet: conveyors
func _mission_09(scrap: EnemyStats, cruiser: EnemyStats, drone: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_09", "Scrap Gauntlet", "The belt decides your lane.", 64.0, Color(0.28, 0.14, 0.1), boss, &"scrap", 4, 2.4, 2, &"scrap")
	m.waves = _sector2_wave_kit(scrap, cruiser, drone, mid)
	return m


# Stage 10 — Dawn Gate: solar flares
func _mission_10(guard: EnemyStats, ace: EnemyStats, raider: EnemyStats, mid: EnemyStats, boss: EnemyStats) -> MissionData:
	var m := _mission_base(&"mission_10", "Dawn Gate", "Climb the flare. Break the dawn.", 68.0, Color(0.35, 0.12, 0.08), boss, &"flare", 5, 2.6, 2, &"flare")
	m.waves = _sector2_wave_kit(guard, ace, raider, mid, true)
	return m


func _sector2_wave_kit(a: EnemyStats, b: EnemyStats, c: EnemyStats, mid: EnemyStats, finale: bool = false) -> Array[WaveDef]:
	## Shared Sector 2 pacing scaffold — denser than Sector 1, still hybrid clears.
	var climax_clear := 22.0 if finale else 20.0
	return [
		_wave("Act 1 — Opener", 1.0, [
			_entry(a, 0.0, Vector2(240, -50), 5, &"v", 54.0, "s2_v1"),
			_entry(b, 1.3, Vector2(240, -55), 4, &"line", 70.0),
			_entry(a, 1.3, Vector2(240, -50), 5, &"arc", 50.0, "s2_a1"),
			_entry(c, 1.2, Vector2(140, -55)),
			_entry(c, 0.3, Vector2(340, -55)),
		], true, 14.0),
		_wave("Act 1 — Sweep", 1.4, [
			_entry(b, 0.0, Vector2(100, -50), 3, &"column", 40.0),
			_entry(b, 0.3, Vector2(380, -50), 3, &"column", 40.0),
			_entry(a, 1.2, Vector2(240, -55), 6, &"diamond", 48.0, "s2_d1"),
			_entry(a, 1.2, Vector2(240, -55), 7, &"circle", 56.0, "s2_c1"),
			_entry(c, 1.2, Vector2(240, -50), 3, &"wave", 64.0),
			_entry(a, 1.2, Vector2(240, -55), 5, &"inv_v", 52.0, "s2_i1"),
		], true, 14.0),
		_wave("Act 2 — Escalation", 1.5, [
			_entry(c, 0.0, Vector2(90, -50), 3, &"column", 38.0),
			_entry(c, 0.3, Vector2(390, -50), 3, &"column", 38.0),
			_entry(b, 1.1, Vector2(240, -55), 4, &"line", 68.0),
			_entry(a, 1.1, Vector2(240, -50), 6, &"cross", 46.0, "s2_x1"),
			_entry(a, 1.1, Vector2(240, -55), 7, &"spiral", 56.0, "s2_sp1"),
			_entry(b, 1.1, Vector2(240, -55), 4, &"arc", 58.0),
			_entry(c, 1.0, Vector2(240, -50), 3, &"v", 70.0),
		], true, 16.0),
		_wave("Act 2 — Pressure", 1.5, [
			_entry(b, 0.0, Vector2(240, -50), 4, &"wave", 62.0),
			_entry(a, 1.1, Vector2(240, -55), 7, &"v", 48.0, "s2_v2"),
			_entry(c, 1.0, Vector2(110, -50), 3, &"column", 38.0),
			_entry(c, 0.2, Vector2(370, -50), 3, &"column", 38.0),
			_entry(b, 1.1, Vector2(240, -55), 4, &"box", 58.0),
			_entry(a, 1.2, Vector2(240, -50), 6, &"arc", 50.0, "s2_a2"),
		], true, 16.0),
		_wave("Act 3 — Mid-Boss", 2.5, [_entry(mid, 0.0, Vector2(240, -75))], true, 0.0),
		_wave("Act 4 — Build", 2.3, [
			_entry(a, 0.0, Vector2(240, -55), 6, &"v", 50.0, "s2_bv"),
			_entry(b, 1.0, Vector2(100, -50), 3, &"column", 40.0),
			_entry(b, 0.2, Vector2(380, -50), 3, &"column", 40.0),
			_entry(c, 1.2, Vector2(240, -55), 4, &"line", 70.0),
			_entry(a, 1.2, Vector2(240, -50), 6, &"diamond", 48.0, "s2_bd"),
			_entry(c, 1.1, Vector2(240, -55), 3, &"wave", 66.0),
		], true, 16.0),
		_wave("Act 5 — Climax", 2.7, [
			_entry(c, 0.0, Vector2(90, -50), 4, &"column", 36.0),
			_entry(c, 0.0, Vector2(390, -50), 4, &"column", 36.0),
			_entry(b, 1.0, Vector2(240, -55), 4, &"v", 60.0),
			_entry(a, 0.9, Vector2(240, -50), 7, &"arc", 46.0, "s2_fa"),
			_entry(a, 1.1, Vector2(240, -55), 10, &"star", 52.0, "s2_fstar"),
			_entry(b, 1.0, Vector2(240, -55), 4, &"box", 62.0),
			_entry(c, 1.1, Vector2(240, -50), 4, &"wave", 64.0),
			_entry(a, 1.0, Vector2(240, -55), 6, &"cross", 48.0, "s2_fx"),
			_entry(b, 1.1, Vector2(160, -50)),
			_entry(b, 0.3, Vector2(320, -50)),
		], true, climax_clear),
	]


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (%s)" % [path, err])
	else:
		print("Saved ", path)