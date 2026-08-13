class_name BossPatterns
extends RefCounted
## Boss & mid-boss attack routines, keyed by EnemyStats.boss_archetype instead
## of display-name string matching. Adding a boss = a new archetype value + one
## branch here; enemy_base.gd itself never grows per-boss again.
##
## All functions take the boss enemy node and read/write its stats + a few
## per-enemy fields (_boss_phase, _armor_angle, _teleport_cd, _t, _origin_x).

const ARCH_ORBITAL := &"orbital"        ## Rotating-armor platform
const ARCH_MEGALITH := &"megalith"      ## Heavy wide volleys, low hover
const ARCH_LEVIATHAN := &"leviathan"    ## Ethereal waves + illusion decoys
const ARCH_FABRICATION := &"fabrication" ## Grid/cross denial + drone adds
const ARCH_OMEGA := &"omega"            ## Peak-density rings + stitch fire
const ARCH_KALEIDOSCOPE := &"kaleidoscope" ## Sector 2: mirrored prism fans
const ARCH_TEMPEST := &"tempest"        ## Sector 2: lightning columns
const ARCH_CHOIR := &"choir"            ## Sector 2: delayed ghost rings
const ARCH_JUNKYARD := &"junkyard"      ## Sector 2: scrap volleys + adds
const ARCH_DAWN := &"dawn"              ## Sector 2: solar flare wash
const ARCH_STALKER := &"stalker"        ## Mid: teleport + aimed bursts
const ARCH_DRILL := &"drill"            ## Mid: wide fans
const ARCH_OVERSEER := &"overseer"      ## Mid: crosses
const ARCH_ACE := &"ace"                ## Mid: twin aimed pressure
const ARCH_STORM := &"storm"            ## Mid: rings
const ARCH_TRANSPORT := &"transport"    ## Mid: Heavy Transport side pressure
const ARCH_PRISM := &"prism"            ## Mid: steep ricochet fans
const ARCH_COIL := &"coil"              ## Mid: flanking lightning bolts
const ARCH_ECHO := &"echo"              ## Mid: delayed ghost copies
const ARCH_TYRANT := &"tyrant"          ## Mid: lane-filling scrap fans
const ARCH_HERALD := &"herald"          ## Mid: solar flare bursts


# ---------------------------------------------------------------------------
# Fire dispatch
# ---------------------------------------------------------------------------

static func fire(boss: Node) -> void:
	var stats: EnemyStats = boss.get("stats") as EnemyStats
	if stats == null:
		return
	var phase: int = boss.get("_boss_phase")
	var muzzle: Vector2 = boss.global_position + Vector2(0, 24)
	var spd := stats.projectile_speed
	var dmg := float(stats.contact_damage)
	var arch := stats.boss_archetype
	if stats.is_mid_boss:
		_fire_mid(boss, arch, phase, muzzle, spd, dmg, stats)
	else:
		match arch:
			ARCH_ORBITAL:
				_fire_orbital(boss, phase, muzzle, spd, dmg, stats)
			ARCH_MEGALITH:
				_fire_megalith(boss, phase, muzzle, spd, dmg, stats)
			ARCH_LEVIATHAN:
				_fire_leviathan(boss, phase, muzzle, spd, dmg)
			ARCH_FABRICATION:
				_fire_fabrication(boss, phase, muzzle, spd, dmg)
				if randf() < (0.14 + 0.08 * float(phase)):
					spawn_fabricated_drone(boss)
			ARCH_OMEGA:
				_fire_omega(boss, phase, muzzle, spd, dmg, stats)
			ARCH_KALEIDOSCOPE:
				_fire_kaleidoscope(boss, phase, muzzle, spd, dmg, stats)
			ARCH_TEMPEST:
				_fire_tempest(boss, phase, muzzle, spd, dmg, stats)
			ARCH_CHOIR:
				_fire_choir(boss, phase, muzzle, spd, dmg, stats)
			ARCH_JUNKYARD:
				_fire_junkyard(boss, phase, muzzle, spd, dmg, stats)
				if randf() < (0.10 + 0.06 * float(phase)):
					spawn_fabricated_drone(boss)
			ARCH_DAWN:
				_fire_dawn(boss, phase, muzzle, spd, dmg, stats)
			_:
				spread_fan(boss, muzzle, spd, dmg, 1 + phase * 2, 0.55)
	AudioBus.play_enemy_shoot()


static func _fire_mid(boss: Node, arch: StringName, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	match arch:
		ARCH_STALKER:
			aimed(boss, muzzle, spd * 1.05, dmg, 3 + phase, 0.18)
			boss.set("_fire_timer", stats.fire_interval * (0.9 - 0.1 * float(phase)))
		ARCH_DRILL:
			spread_fan(boss, muzzle, spd * 0.9, dmg, 3 + phase, 0.7)
			boss.set("_fire_timer", stats.fire_interval * 0.95)
		ARCH_OVERSEER:
			cross(boss, muzzle, spd, dmg)
			if phase >= 1:
				spread_fan(boss, muzzle, spd * 0.85, dmg, 3, 0.35)
			boss.set("_fire_timer", stats.fire_interval * (0.9 - 0.08 * float(phase)))
		ARCH_ACE:
			aimed(boss, muzzle, spd * 1.1, dmg, 2 + phase, 0.12)
			spread_fan(boss, muzzle, spd, dmg, 3, 0.4)
			boss.set("_fire_timer", stats.fire_interval * 0.85)
		ARCH_STORM:
			ring(boss, muzzle, spd * 0.75, dmg, 6 + phase)
			aimed(boss, muzzle, spd, dmg, 1 + phase, 0.1)
			boss.set("_fire_timer", stats.fire_interval * 0.88)
		ARCH_TRANSPORT:
			_fire_transport(boss, phase, muzzle, spd, dmg, stats)
		ARCH_PRISM:
			_fire_prism(boss, phase, muzzle, spd, dmg, stats)
		ARCH_COIL:
			_fire_coil(boss, phase, muzzle, spd, dmg, stats)
		ARCH_ECHO:
			_fire_echo(boss, phase, muzzle, spd, dmg, stats)
		ARCH_TYRANT:
			spread_fan(boss, muzzle, spd * 0.7, dmg, 5 + phase, 0.95, {"scale": 1.25, "lifetime": 3.6, "color": Color(0.95, 0.55, 0.3)})
			boss.set("_fire_timer", stats.fire_interval * 0.92)
		ARCH_HERALD:
			spread_fan(boss, muzzle, spd * 0.88, dmg, 4 + phase, 0.7, {"color": Color(1.0, 0.65, 0.3), "scale": 1.1})
			aimed(boss, muzzle, spd * 1.05, dmg, 1 + phase, 0.08)
			boss.set("_fire_timer", stats.fire_interval * 0.86)
		_:
			spread_fan(boss, muzzle, spd, dmg, 3 + phase, 0.5)
			boss.set("_fire_timer", stats.fire_interval * (0.95 - 0.08 * float(phase)))


static func _fire_orbital(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Rotating armor boss: sweeping arcs that punish standing in one lane.
	var arms := 3 + phase
	var base: float = boss.get("_armor_angle")
	for i in arms:
		var a := base + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a) * 0.85, 0.55 + 0.35 * absf(cos(a))).normalized()
		spawn_shot(boss, muzzle, dir * spd, dmg)
	if phase >= 1:
		aimed(boss, muzzle, spd * 0.95, dmg, 1 + phase, 0.08)
	boss.set("_fire_timer", stats.fire_interval * (0.9 - 0.12 * float(phase)))


static func _fire_megalith(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Heavy wide volleys — slow, chunky, hard to squeeze through.
	var count := 5 + phase * 2
	spread_fan(boss, muzzle, spd * 0.72, dmg, count, 0.95, {"scale": 1.35, "lifetime": 4.0})
	if phase >= 2 and int(boss.get("_t") * 2.0) % 2 == 0:
		for side in [-1.0, 1.0]:
			spawn_shot(boss, muzzle + Vector2(side * 40.0, 0), Vector2(side * 0.35, 1).normalized() * spd * 0.8, dmg, {"scale": 1.2})
	boss.set("_fire_timer", stats.fire_interval * (1.05 - 0.1 * float(phase)))


static func _fire_leviathan(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	## Ethereal wavy shots + faint "illusion" extras that drift oddly.
	var count := 4 + phase
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var a := lerpf(-0.55, 0.55, t)
		var dir := Vector2(a, 1).normalized()
		spawn_shot(boss, muzzle, dir * spd * 0.9, dmg, {
			"wave_amp": 18.0 + 8.0 * float(phase),
			"wave_freq": 6.0,
			"color": Color(0.85, 0.45, 1.0),
			"scale": 0.9,
		})
	var illusions := 2 + phase
	for i in illusions:
		var a2 := randf_range(-0.7, 0.7)
		spawn_shot(boss, muzzle + Vector2(randf_range(-30.0, 30.0), 0), Vector2(a2, 1).normalized() * spd * 0.55, dmg * 0.75, {
			"wave_amp": 28.0,
			"wave_freq": 4.5,
			"color": Color(0.7, 0.35, 0.95, 0.55),
			"scale": 0.7,
			"lifetime": 3.5,
		})
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (0.85 - 0.1 * float(phase)))


static func _fire_fabrication(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	## Grid / cross denial while adds chew DPS.
	cross(boss, muzzle, spd * 0.95, dmg)
	if phase >= 1:
		spread_fan(boss, muzzle, spd, dmg, 3 + phase, 0.4)
	if phase >= 2:
		ring(boss, muzzle, spd * 0.65, dmg, 8)
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (0.88 - 0.1 * float(phase)))


static func _fire_omega(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Peak density: ring bursts + aimed stitch fire.
	var ring_n := 8 + phase * 2
	ring(boss, muzzle, spd * 0.7, dmg, ring_n)
	aimed(boss, muzzle, spd * 1.05, dmg, 2 + phase, 0.1)
	if phase >= 2:
		spread_fan(boss, muzzle, spd * 0.85, dmg, 5, 0.55)
	boss.set("_fire_timer", stats.fire_interval * (0.75 - 0.08 * float(phase)))


static func _fire_kaleidoscope(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Six-fold prism fans — every shot has a mirrored twin.
	var rot: float = boss.get("_armor_angle")
	var arms := 6
	for i in arms:
		var a := rot + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a), absf(cos(a)) * 0.4 + 0.6).normalized()
		spawn_shot(boss, muzzle, dir * spd, dmg, {
			"color": Color(0.45, 0.9, 1.0),
			"scale": 0.9,
		})
		spawn_shot(boss, muzzle, Vector2(-dir.x, dir.y) * spd, dmg, {
			"color": Color(0.7, 0.95, 1.0),
			"scale": 0.85,
		})
	if phase >= 1:
		aimed(boss, muzzle, spd * 0.95, dmg, 1 + phase, 0.06)
	if phase >= 2:
		for side in [-1.0, 1.0]:
			spawn_shot(boss, muzzle + Vector2(side * 28.0, 0), Vector2(side * 0.9, 0.45).normalized() * spd * 0.85, dmg, {
				"color": Color(0.55, 0.85, 1.0),
				"wave_amp": 14.0,
				"wave_freq": 7.0,
			})
	boss.set("_fire_timer", stats.fire_interval * (0.86 - 0.1 * float(phase)))


static func _fire_tempest(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Lightning columns that stitch the lanes, plus a tracking bolt.
	var cols := [-78.0, 0.0, 78.0] if phase >= 1 else [-56.0, 56.0]
	for col in cols:
		var bolts := 2 + phase
		for k in bolts:
			var origin := muzzle + Vector2(col, float(k) * -10.0)
			var dir := Vector2(0.1 * signf(col), 1).normalized()
			spawn_shot(boss, origin, dir * spd * (1.15 - 0.08 * float(k)), dmg, {
				"color": Color(0.4, 0.85, 1.0),
				"scale": 0.75,
				"lifetime": 2.2,
			})
	aimed(boss, muzzle, spd * 1.12, dmg, 1 + phase, 0.05)
	if phase >= 2:
		ring(boss, muzzle, spd * 0.68, dmg, 8, {"color": Color(0.55, 0.9, 1.0), "scale": 0.8})
	boss.set("_fire_timer", stats.fire_interval * (0.82 - 0.08 * float(phase)))


static func _fire_choir(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Immediate ring plus a delayed ghost copy — they shoot where the first was.
	ring(boss, muzzle, spd * 0.78, dmg, 7 + phase, {
		"color": Color(0.45, 0.55, 1.0),
		"scale": 0.95,
	})
	aimed(boss, muzzle, spd * 0.9, dmg, 1 + phase, 0.12, {
		"color": Color(0.55, 0.65, 1.0, 0.85),
		"wave_amp": 10.0,
		"wave_freq": 5.0,
	})
	var tree: SceneTree = boss.get_tree()
	if tree:
		var echo_muzzle := muzzle
		var echo_spd := spd
		var echo_dmg := dmg
		var echo_phase := phase
		tree.create_timer(0.38).timeout.connect(func() -> void:
			if not is_instance_valid(boss) or boss.get("alive") == false:
				return
			ring(boss, echo_muzzle, echo_spd * 0.52, echo_dmg * 0.7, 6 + echo_phase, {
				"color": Color(0.4, 0.5, 1.0, 0.45),
				"scale": 0.7,
				"lifetime": 3.2,
			})
		)
	boss.set("_fire_timer", stats.fire_interval * (0.9 - 0.08 * float(phase)))


static func _fire_junkyard(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Irregular scrap: chunky slow shells mixed with jagged fans.
	var count := 4 + phase
	spread_fan(boss, muzzle, spd * 0.68, dmg, count, 0.85, {
		"scale": 1.3,
		"lifetime": 3.8,
		"color": Color(0.9, 0.5, 0.28),
	})
	for i in 2 + phase:
		var a := randf_range(-0.8, 0.8)
		spawn_shot(boss, muzzle + Vector2(randf_range(-36.0, 36.0), 0), Vector2(a, 1).normalized() * spd * randf_range(0.45, 0.7), dmg, {
			"scale": randf_range(0.9, 1.6),
			"color": Color(0.75, 0.45, 0.25),
			"lifetime": 4.0,
		})
	if phase >= 2:
		cross(boss, muzzle, spd * 0.8, dmg, {"color": Color(1.0, 0.55, 0.3), "scale": 1.1})
	boss.set("_fire_timer", stats.fire_interval * (1.0 - 0.08 * float(phase)))


static func _fire_dawn(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Wide solar wash across the lower field, then a tight core stitch.
	spread_fan(boss, muzzle, spd * 0.74, dmg, 7 + phase * 2, 1.12, {
		"scale": 1.25,
		"color": Color(1.0, 0.55, 0.25),
		"lifetime": 3.4,
	})
	aimed(boss, muzzle, spd * 1.08, dmg, 2 + phase, 0.07, {
		"color": Color(1.0, 0.8, 0.4),
		"scale": 0.95,
	})
	if phase >= 1:
		for side in [-1.0, 1.0]:
			spawn_shot(boss, muzzle + Vector2(side * 44.0, 8.0), Vector2(side * 0.25, 1).normalized() * spd * 0.9, dmg, {
				"color": Color(1.0, 0.7, 0.3),
				"scale": 1.15,
			})
	if phase >= 2:
		ring(boss, muzzle, spd * 0.66, dmg, 10, {"color": Color(1.0, 0.6, 0.2), "scale": 0.85})
	boss.set("_fire_timer", stats.fire_interval * (0.8 - 0.08 * float(phase)))


static func _fire_transport(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Side-gun pressure: outbound shots from the wings plus a slow center fan.
	for side in [-1.0, 1.0]:
		var wing := muzzle + Vector2(side * 38.0, 10.0)
		spawn_shot(boss, wing, Vector2(side * 0.5, 1).normalized() * spd * 0.82, dmg, {
			"scale": 1.15,
			"color": Color(0.55, 0.8, 1.0),
		})
		if phase >= 1:
			spawn_shot(boss, wing, Vector2(side * 0.22, 1).normalized() * spd * 0.9, dmg)
	spread_fan(boss, muzzle, spd * 0.75, dmg, 3 + phase, 0.32)
	boss.set("_fire_timer", stats.fire_interval * (0.95 - 0.06 * float(phase)))


static func _fire_prism(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Steep ricochet angles — almost horizontal, then diving.
	for dir in [Vector2(0.95, 0.32), Vector2(-0.95, 0.32), Vector2(0.55, 0.84), Vector2(-0.55, 0.84)]:
		spawn_shot(boss, muzzle, dir.normalized() * spd, dmg, {
			"color": Color(0.5, 0.9, 1.0),
			"scale": 0.9,
		})
	if phase >= 1:
		aimed(boss, muzzle, spd * 1.05, dmg, 2, 0.1)
	boss.set("_fire_timer", stats.fire_interval * (0.88 - 0.06 * float(phase)))


static func _fire_coil(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Flanking lightning bolts with a small ring.
	ring(boss, muzzle, spd * 0.72, dmg, 5 + phase, {"color": Color(0.4, 0.85, 1.0), "scale": 0.8})
	for side in [-1.0, 1.0]:
		spawn_shot(boss, muzzle + Vector2(side * 50.0, 0), Vector2(0, 1) * spd * 1.18, dmg, {
			"color": Color(0.55, 0.9, 1.0),
			"scale": 1.05,
		})
	if phase >= 1:
		aimed(boss, muzzle, spd, dmg, 1 + phase, 0.08)
	boss.set("_fire_timer", stats.fire_interval * 0.86)


static func _fire_echo(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	## Live aimed burst plus a slower ghost copy of the same volley.
	aimed(boss, muzzle, spd * 1.05, dmg, 2 + phase, 0.14)
	aimed(boss, muzzle, spd * 0.52, dmg * 0.75, 2 + phase, 0.14, {
		"color": Color(0.4, 0.55, 1.0, 0.5),
		"scale": 0.75,
		"wave_amp": 16.0,
		"wave_freq": 4.5,
		"lifetime": 3.4,
	})
	boss.set("_fire_timer", stats.fire_interval * 0.9)


static func spawn_fabricated_drone(boss: Node) -> void:
	var pool: ProjectilePool = boss.get("projectile_pool")
	var parent := boss.get_parent()
	if parent == null or pool == null:
		return
	var scene: PackedScene = load("res://scenes/entities/enemy_base.tscn")
	var drone_stats: EnemyStats = load("res://resources/enemies/drone.tres")
	if scene == null or drone_stats == null:
		return
	var e: Node = scene.instantiate()
	parent.add_child(e)
	e.global_position = boss.global_position + Vector2(randf_range(-60.0, 60.0), 40.0)
	if e.has_method("setup"):
		e.setup(drone_stats, pool, boss.get("scroll_speed"))


# ---------------------------------------------------------------------------
# Movement (BOSS pattern)
# ---------------------------------------------------------------------------

static func move(boss: Node, delta: float) -> void:
	var stats: EnemyStats = boss.get("stats") as EnemyStats
	if stats == null:
		return
	var arch := stats.boss_archetype
	var t: float = boss.get("_t")
	var origin_x: float = boss.get("_origin_x")
	var speed := stats.move_speed

	# Stalker family: periodically vanish and reposition.
	if arch == ARCH_STALKER:
		var cd: float = boss.get("_teleport_cd")
		cd -= delta
		if cd <= 0.0:
			cd = randf_range(3.4, 5.0)
			var vp: Vector2 = boss.get_viewport_rect().size
			boss.global_position = Vector2(randf_range(80.0, vp.x - 80.0), randf_range(80.0, 200.0))
			boss.set("_origin_x", boss.global_position.x)
			EventBus.gimmick_toast.emit("RELOCATING")
		boss.set("_teleport_cd", cd)

	var target_y := 120.0
	match arch:
		ARCH_MEGALITH, ARCH_JUNKYARD:
			target_y = 100.0
		ARCH_DAWN:
			target_y = 110.0
		ARCH_KALEIDOSCOPE:
			target_y = 114.0
		ARCH_CHOIR:
			target_y = 118.0
	if boss.global_position.y < target_y:
		boss.global_position.y += speed * delta
	else:
		var sway := 140.0
		var rate := 0.8
		match arch:
			ARCH_ORBITAL:
				sway = 100.0
			ARCH_KALEIDOSCOPE:
				sway = 168.0
				rate = 1.15
			ARCH_TEMPEST:
				sway = 128.0
				rate = 1.35
			ARCH_CHOIR:
				sway = 88.0
				rate = 0.55
			ARCH_JUNKYARD:
				sway = 110.0
				rate = 0.65
			ARCH_DAWN:
				sway = 120.0
				rate = 0.9
		boss.global_position.x = origin_x + sin(t * rate) * sway
		boss.global_position.x = clampf(boss.global_position.x, 60.0, boss.get_viewport_rect().size.x - 60.0)
		if arch == ARCH_TEMPEST:
			boss.global_position.y = target_y + sin(t * 1.8) * 10.0


# ---------------------------------------------------------------------------
# Armor
# ---------------------------------------------------------------------------

## Orbital Defense Platform: rotating plating reduces frontal hits
## unless the shot has armor pierce (Focused Laser Lv2+).
static func armor_mult(stats: EnemyStats, armor_angle: float) -> float:
	if stats == null or not stats.is_boss or stats.is_mid_boss:
		return 1.0
	var arch := stats.boss_archetype
	if arch == ARCH_ORBITAL and absf(sin(armor_angle)) > 0.65:
		return 0.55
	if arch == ARCH_KALEIDOSCOPE and absf(cos(armor_angle)) > 0.72:
		return 0.6
	if arch == ARCH_DAWN and absf(sin(armor_angle * 0.5)) > 0.82:
		return 0.7
	return 1.0


# ---------------------------------------------------------------------------
# Shot launchers (shared with fodder patterns)
# ---------------------------------------------------------------------------

static func spawn_shot(boss: Node, muzzle: Vector2, velocity: Vector2, dmg: float, opts: Dictionary = {}) -> void:
	var pool: ProjectilePool = boss.get("projectile_pool")
	if pool:
		pool.spawn_enemy(muzzle, velocity, dmg, opts)


static func spread_fan(boss: Node, muzzle: Vector2, spd: float, dmg: float, count: int, width: float, opts: Dictionary = {}) -> void:
	count = maxi(count, 1)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var a := lerpf(-width, width, t)
		spawn_shot(boss, muzzle, Vector2(a, 1).normalized() * spd, dmg, opts)


static func aimed(boss: Node, muzzle: Vector2, spd: float, dmg: float, count: int, spread: float, opts: Dictionary = {}) -> void:
	var aim := Vector2(0, 1)
	var player := boss.get_tree().get_first_node_in_group("player")
	if player is Node2D and is_instance_valid(player):
		aim = ((player as Node2D).global_position - muzzle).normalized()
		if aim.y < 0.2:
			aim.y = 0.2
			aim = aim.normalized()
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var angled := aim.rotated(lerpf(-spread, spread, t))
		spawn_shot(boss, muzzle, angled * spd, dmg, opts)


static func cross(boss: Node, muzzle: Vector2, spd: float, dmg: float, opts: Dictionary = {}) -> void:
	for dir in [Vector2(0, 1), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.9, 0.35), Vector2(-0.9, 0.35)]:
		spawn_shot(boss, muzzle, dir.normalized() * spd, dmg, opts)


static func ring(boss: Node, muzzle: Vector2, spd: float, dmg: float, count: int, opts: Dictionary = {}) -> void:
	var t_rot: float = boss.get("_t")
	for i in count:
		var a := TAU * float(i) / float(count) + t_rot * 0.4
		# Bias downward so portrait play stays fair.
		var dir := Vector2(sin(a), absf(cos(a)) * 0.35 + 0.65).normalized()
		spawn_shot(boss, muzzle, dir * spd, dmg, opts)