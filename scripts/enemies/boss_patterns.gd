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
			spiral_shot(boss, muzzle, spd, dmg, 1.3 if phase % 2 == 0 else -1.3)
			if phase >= 1:
				helix_pair(boss, muzzle, spd * 0.9, dmg)
			boss.set("_fire_timer", stats.fire_interval * (1.1 - 0.05 * float(phase)))
		ARCH_DRILL:
			spread_fan(boss, muzzle, spd * 0.85, dmg, 3, 0.7, {"curve": 0.5})
			if phase >= 1:
				arc_shot(boss, muzzle, spd * 0.9, dmg, 1.0)
			boss.set("_fire_timer", stats.fire_interval * 1.08)
		ARCH_OVERSEER:
			helix_pair(boss, muzzle, spd * 0.92, dmg)
			if phase >= 1:
				spiral_burst(boss, muzzle, spd * 0.7, dmg, 4, 1.0, {"scale": 0.85})
			boss.set("_fire_timer", stats.fire_interval * 1.06)
		ARCH_ACE:
			arc_shot(boss, muzzle, spd * 1.0, dmg, 1.15)
			arc_shot(boss, muzzle, spd * 1.0, dmg, -1.15)
			if phase >= 1:
				spiral_shot(boss, muzzle, spd * 0.95, dmg, 1.2)
			boss.set("_fire_timer", stats.fire_interval * 1.05)
		ARCH_STORM:
			spiral_burst(boss, muzzle, spd * 0.75, dmg, 5, 1.1, {"scale": 0.9})
			if phase >= 1:
				helix_pair(boss, muzzle, spd * 0.88, dmg)
			boss.set("_fire_timer", stats.fire_interval * 1.08)
		ARCH_TRANSPORT:
			_fire_transport(boss, phase, muzzle, spd, dmg, stats)
		ARCH_PRISM:
			_fire_prism(boss, phase, muzzle, spd, dmg, stats)
		ARCH_COIL:
			_fire_coil(boss, phase, muzzle, spd, dmg, stats)
		ARCH_ECHO:
			_fire_echo(boss, phase, muzzle, spd, dmg, stats)
		ARCH_TYRANT:
			spread_fan(boss, muzzle, spd * 0.72, dmg, 3, 0.75, {"scale": 1.2, "lifetime": 3.6, "color": Color(0.95, 0.55, 0.3), "curve": 0.5})
			if phase >= 1:
				arc_shot(boss, muzzle, spd * 0.78, dmg, 1.1, {"scale": 1.1})
			boss.set("_fire_timer", stats.fire_interval * 1.08)
		ARCH_HERALD:
			spiral_burst(boss, muzzle, spd * 0.82, dmg, 4, 1.05, {"color": Color(1.0, 0.65, 0.3), "scale": 1.0})
			if phase >= 1:
				arc_shot(boss, muzzle, spd * 0.95, dmg, -1.0)
			boss.set("_fire_timer", stats.fire_interval * 1.06)
		_:
			spiral_burst(boss, muzzle, spd * 0.8, dmg, 3, 1.0, {"scale": 0.9})
			boss.set("_fire_timer", stats.fire_interval * 1.1)


static func _fire_orbital(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var arms := 3 if phase == 0 else 4
	var base: float = boss.get("_armor_angle")
	for i in arms:
		var a := base + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a) * 0.85, 0.55 + 0.35 * absf(cos(a))).normalized()
		var o := {"curve": 1.1 if i % 2 == 0 else -1.1}
		spawn_shot(boss, muzzle, dir * spd, dmg, o)
	if phase >= 1:
		spiral_shot(boss, muzzle, spd * 0.9, dmg, 1.25 if phase == 1 else -1.25)
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.72, dmg, 6, 1.35, {"scale": 0.85})
	boss.set("_fire_timer", stats.fire_interval * (1.05 - 0.06 * float(phase)))


static func _fire_megalith(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var count := 4 if phase == 0 else 5
	spread_fan(boss, muzzle, spd * 0.72, dmg, count, 0.85, {"scale": 1.3, "lifetime": 4.0, "curve": 0.55})
	if phase >= 1:
		for side in [-1.0, 1.0]:
			arc_shot(boss, muzzle + Vector2(side * 38.0, 6.0), spd * 0.82, dmg, side * 1.0, {"scale": 1.05})
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.65, dmg, 5, 1.0, {"scale": 0.9})
	boss.set("_fire_timer", stats.fire_interval * (1.12 - 0.07 * float(phase)))


static func _fire_leviathan(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	var count := 3 if phase == 0 else 4
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var a := lerpf(-0.5, 0.5, t)
		var dir := Vector2(a, 1).normalized()
		var o := {
			"wave_amp": 18.0 + 8.0 * float(phase),
			"wave_freq": 6.0,
			"color": Color(0.85, 0.45, 1.0),
			"scale": 0.9,
			"curve": 0.45 * (1.0 if i % 2 == 0 else -1.0),
		}
		spawn_shot(boss, muzzle, dir * spd * 0.9, dmg, o)
	if phase >= 1:
		spiral_burst(boss, muzzle + Vector2(0, 8), spd * 0.58, dmg * 0.7, 4, 1.2, {
			"color": Color(0.7, 0.35, 0.95, 0.55),
			"scale": 0.7,
			"lifetime": 3.5,
		})
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (1.02 - 0.06 * float(phase)))


static func _fire_fabrication(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	if phase == 0:
		helix_pair(boss, muzzle, spd * 0.95, dmg)
		cross(boss, muzzle, spd * 0.88, dmg, {"scale": 0.9})
	else:
		spiral_burst(boss, muzzle, spd * 0.75, dmg, 5, 1.0, {"scale": 0.9})
		if phase >= 1:
			helix_pair(boss, muzzle, spd * 0.9, dmg)
		if phase >= 2:
			cross(boss, muzzle, spd * 0.82, dmg)
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (1.08 - 0.07 * float(phase)))


static func _fire_omega(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	if phase == 0:
		spiral_burst(boss, muzzle, spd * 0.72, dmg, 6, 1.15, {"scale": 0.9})
		helix_pair(boss, muzzle, spd * 0.92, dmg)
	else:
		spiral_burst(boss, muzzle, spd * 0.68, dmg, 7, -1.2, {"scale": 0.88})
		aimed(boss, muzzle, spd * 1.0, dmg, 1, 0.0)
		if phase >= 1:
			spiral_shot(boss, muzzle + Vector2(22, 0), spd * 0.95, dmg, 1.4)
			spiral_shot(boss, muzzle + Vector2(-22, 0), spd * 0.95, dmg, -1.4)
		if phase >= 2:
			arc_shot(boss, muzzle, spd * 0.88, dmg, 1.3, {"scale": 1.0})
			arc_shot(boss, muzzle, spd * 0.88, dmg, -1.3, {"scale": 1.0})
	boss.set("_fire_timer", stats.fire_interval * (1.02 - 0.07 * float(phase)))


static func _fire_kaleidoscope(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var rot: float = boss.get("_armor_angle")
	var arms := 5 if phase == 0 else 6
	for i in arms:
		var a := rot + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a), absf(cos(a)) * 0.4 + 0.6).normalized()
		var o := {"color": Color(0.45, 0.9, 1.0), "scale": 0.9, "curve": 0.95 if i % 2 == 0 else -0.95}
		spawn_shot(boss, muzzle, dir * spd, dmg, o)
	if phase >= 1:
		spiral_burst(boss, muzzle, spd * 0.78, dmg, 4, -1.15, {"color": Color(0.7, 0.95, 1.0), "scale": 0.82})
	if phase >= 2:
		helix_pair(boss, muzzle, spd * 0.88, dmg)
	boss.set("_fire_timer", stats.fire_interval * (1.08 - 0.06 * float(phase)))


static func _fire_tempest(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var cols := [-64.0, 64.0] if phase == 0 else [-78.0, 0.0, 78.0]
	for col in cols:
		var origin := muzzle + Vector2(col, 0)
		arc_shot(boss, origin, spd * 0.92, dmg, signf(col) * 0.85, {"color": Color(0.4, 0.85, 1.0), "scale": 0.78, "lifetime": 2.4})
		if phase >= 2 and col != 0.0:
			arc_shot(boss, origin + Vector2(0, -12), spd * 0.88, dmg, -signf(col) * 0.7, {"color": Color(0.55, 0.9, 1.0), "scale": 0.72})
	if phase >= 1:
		helix_pair(boss, muzzle, spd * 0.9, dmg)
	boss.set("_fire_timer", stats.fire_interval * (1.06 - 0.05 * float(phase)))


static func _fire_choir(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spiral_burst(boss, muzzle, spd * 0.76, dmg, 5, 1.05, {"color": Color(0.45, 0.55, 1.0), "scale": 0.92})
	helix_pair(boss, muzzle, spd * 0.88, dmg)
	var tree: SceneTree = boss.get_tree()
	if tree:
		var echo_muzzle := muzzle
		var echo_spd := spd
		var echo_dmg := dmg
		var echo_phase := phase
		tree.create_timer(0.5).timeout.connect(func() -> void:
			if not is_instance_valid(boss) or boss.get("alive") == false:
				return
			spiral_burst(boss, echo_muzzle, echo_spd * 0.55, echo_dmg * 0.65, 4 + echo_phase, -1.0, {
				"color": Color(0.4, 0.5, 1.0, 0.45),
				"scale": 0.68,
				"lifetime": 3.2,
			})
		)
	boss.set("_fire_timer", stats.fire_interval * (1.12 - 0.06 * float(phase)))


static func _fire_junkyard(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spread_fan(boss, muzzle, spd * 0.68, dmg, 3, 0.75, {"scale": 1.2, "lifetime": 3.8, "color": Color(0.9, 0.5, 0.28), "curve": 0.6})
	for i in 2:
		var dir := 1.0 if i == 0 else -1.0
		arc_shot(boss, muzzle + Vector2(dir * 32.0, 4.0), spd * randf_range(0.5, 0.75), dmg, dir * 0.9, {"scale": randf_range(0.95, 1.3), "color": Color(0.75, 0.45, 0.25), "lifetime": 4.0})
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.62, dmg, 4, -1.0, {"color": Color(1.0, 0.55, 0.3), "scale": 0.85})
	boss.set("_fire_timer", stats.fire_interval * (1.15 - 0.06 * float(phase)))


static func _fire_dawn(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spiral_burst(boss, muzzle, spd * 0.74, dmg, 5 + phase * 2, 1.15, {"scale": 1.15, "color": Color(1.0, 0.55, 0.25), "lifetime": 3.4})
	if phase >= 1:
		helix_pair(boss, muzzle, spd * 0.92, dmg)
		for side in [-1.0, 1.0]:
			arc_shot(boss, muzzle + Vector2(side * 44.0, 8.0), spd * 0.88, dmg, side * 1.0, {"color": Color(1.0, 0.7, 0.3), "scale": 1.0})
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.62, dmg, 6, -1.2, {"color": Color(1.0, 0.6, 0.2), "scale": 0.82})
	boss.set("_fire_timer", stats.fire_interval * (1.04 - 0.06 * float(phase)))


static func _fire_transport(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	for side in [-1.0, 1.0]:
		var wing := muzzle + Vector2(side * 38.0, 10.0)
		arc_shot(boss, wing, spd * 0.88, dmg, side * 1.15, {"scale": 1.1, "color": Color(0.55, 0.8, 1.0)})
	spiral_burst(boss, muzzle, spd * 0.75, dmg, 3, 0.9, {"scale": 0.85})
	boss.set("_fire_timer", stats.fire_interval * (1.08 - 0.05 * float(phase)))


static func _fire_prism(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	for dir in [Vector2(0.95, 0.32), Vector2(-0.95, 0.32)]:
		var o := {"color": Color(0.5, 0.9, 1.0), "scale": 0.9, "curve": 1.0 if dir.x > 0 else -1.0}
		spawn_shot(boss, muzzle, dir.normalized() * spd, dmg, o)
	helix_pair(boss, muzzle, spd * 0.92, dmg)
	boss.set("_fire_timer", stats.fire_interval * (1.08 - 0.05 * float(phase)))


static func _fire_coil(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spiral_burst(boss, muzzle, spd * 0.72, dmg, 5, 1.0, {"color": Color(0.4, 0.85, 1.0), "scale": 0.8})
	for side in [-1.0, 1.0]:
		arc_shot(boss, muzzle + Vector2(side * 50.0, 0), spd * 1.05, dmg, side * 1.0, {"color": Color(0.55, 0.9, 1.0), "scale": 1.0})
	boss.set("_fire_timer", stats.fire_interval * 1.06)


static func _fire_echo(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	helix_pair(boss, muzzle, spd, dmg)
	spiral_shot(boss, muzzle, spd * 0.9, dmg, 1.15 if phase == 0 else -1.15, {"color": Color(0.4, 0.55, 1.0, 0.5), "scale": 0.75, "lifetime": 3.4})
	boss.set("_fire_timer", stats.fire_interval * 1.06)


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
		if arch == ARCH_LEVIATHAN:
			boss.global_position.x = origin_x + sin(t * 0.85) * 130.0 + sin(t * 1.7) * 38.0
			boss.global_position.y = target_y + cos(t * 1.7) * 14.0
		elif arch == ARCH_OMEGA:
			boss.global_position.x = origin_x + sin(t * 0.72) * 118.0
			boss.global_position.y = target_y + sin(t * 1.45) * 12.0 + cos(t * 0.72) * 6.0
		elif arch == ARCH_KALEIDOSCOPE:
			var dash := 1.0
			if fmod(t, 3.4) < 0.55:
				dash = 2.2
			boss.global_position.x = origin_x + sin(t * 1.15 * dash) * 168.0
			boss.global_position.y = target_y + sin(t * 2.3) * 8.0
		elif arch == ARCH_DAWN:
			boss.global_position.x = origin_x + sin(t * 0.9) * 120.0
			boss.global_position.y = target_y + absf(sin(t * 0.65)) * 18.0
		elif arch == ARCH_TEMPEST:
			boss.global_position.x = origin_x + sin(t * 1.35) * 128.0
			boss.global_position.y = target_y + sin(t * 1.8) * 10.0 + cos(t * 0.9) * 6.0
		elif arch == ARCH_ORBITAL:
			boss.global_position.x = origin_x + sin(t * 0.6) * 100.0
			boss.global_position.y = target_y + cos(t * 0.6) * 14.0
		elif arch == ARCH_CHOIR:
			boss.global_position.x = origin_x + sin(t * 0.55) * 88.0 + sin(t * 1.6) * 22.0
			boss.global_position.y = target_y + sin(t * 0.9) * 6.0
		elif arch == ARCH_JUNKYARD:
			boss.global_position.x = origin_x + sin(t * 0.65) * 110.0
			boss.global_position.y = target_y + sin(t * 1.1) * 7.0 if fmod(t, 5.0) > 1.0 else boss.global_position.y
		else:
			boss.global_position.x = origin_x + sin(t * 0.8) * 140.0
		boss.global_position.x = clampf(boss.global_position.x, 60.0, boss.get_viewport_rect().size.x - 60.0)


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
		var dir := Vector2(sin(a), absf(cos(a)) * 0.35 + 0.65).normalized()
		spawn_shot(boss, muzzle, dir * spd, dmg, opts)


static func spiral_shot(boss: Node, muzzle: Vector2, spd: float, dmg: float, curve: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	o["curve"] = curve
	var player := boss.get_tree().get_first_node_in_group("player") if boss.get_tree() else null
	var aim := Vector2(0, 1)
	if player is Node2D and is_instance_valid(player):
		aim = ((player as Node2D).global_position - muzzle).normalized()
		if aim.y < 0.15:
			aim.y = 0.15
			aim = aim.normalized()
	spawn_shot(boss, muzzle, aim * spd, dmg, o)


static func arc_shot(boss: Node, muzzle: Vector2, spd: float, dmg: float, curve: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	o["curve"] = curve
	spawn_shot(boss, muzzle, Vector2(0, 1) * spd, dmg, o)


static func helix_pair(boss: Node, muzzle: Vector2, spd: float, dmg: float, opts: Dictionary = {}) -> void:
	var o1 := opts.duplicate()
	var o2 := opts.duplicate()
	o1["wave_amp"] = 18.0
	o1["wave_freq"] = 6.5
	o2["wave_amp"] = -18.0
	o2["wave_freq"] = 6.5
	spawn_shot(boss, muzzle + Vector2(-8, 0), Vector2(-0.18, 1).normalized() * spd, dmg, o1)
	spawn_shot(boss, muzzle + Vector2(8, 0), Vector2(0.18, 1).normalized() * spd, dmg, o2)


static func spiral_burst(boss: Node, muzzle: Vector2, spd: float, dmg: float, count: int, curve: float, opts: Dictionary = {}) -> void:
	var t_rot: float = boss.get("_t")
	for i in count:
		var a := TAU * float(i) / float(count) + t_rot * 0.5
		var dir := Vector2(sin(a), cos(a) * 0.45 + 0.65).normalized()
		var o := opts.duplicate()
		o["curve"] = curve * (1.0 if i % 2 == 0 else -1.0)
		spawn_shot(boss, muzzle, dir * spd, dmg, o)