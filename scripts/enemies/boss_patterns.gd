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
const ARCH_STALKER := &"stalker"        ## Mid: teleport + aimed bursts
const ARCH_DRILL := &"drill"            ## Mid: wide fans
const ARCH_OVERSEER := &"overseer"      ## Mid: crosses
const ARCH_ACE := &"ace"                ## Mid: twin aimed pressure
const ARCH_STORM := &"storm"            ## Mid: rings


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

	var target_y := 100.0 if arch == ARCH_MEGALITH else 120.0
	if boss.global_position.y < target_y:
		boss.global_position.y += speed * delta
	else:
		var sway := 100.0 if arch == ARCH_ORBITAL else 140.0
		boss.global_position.x = origin_x + sin(t * 0.8) * sway
		boss.global_position.x = clampf(boss.global_position.x, 60.0, boss.get_viewport_rect().size.x - 60.0)


# ---------------------------------------------------------------------------
# Armor
# ---------------------------------------------------------------------------

## Orbital Defense Platform: rotating plating reduces frontal hits
## unless the shot has armor pierce (Focused Laser Lv2+).
static func armor_mult(stats: EnemyStats, armor_angle: float) -> float:
	if stats == null or not stats.is_boss or stats.is_mid_boss:
		return 1.0
	if stats.boss_archetype == ARCH_ORBITAL and absf(sin(armor_angle)) > 0.65:
		return 0.55
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
