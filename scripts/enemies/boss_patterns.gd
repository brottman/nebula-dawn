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
# Telegraph helpers (ghost visuals, no new scenes)
# ---------------------------------------------------------------------------

static func _set_lock(boss: Node, dur: float) -> void:
	if boss.has_method("get"):
		boss.set("_telegraph_lock", maxf(float(boss.get("_telegraph_lock")) if boss.get("_telegraph_lock") != null else 0.0, dur))


static func _ghost_ring(boss: Node, pos: Vector2, color: Color, radius: float, dur: float) -> void:
	var parent: Node = boss.get_parent()
	if parent == null:
		return
	var c := color
	if GameState.reduce_flashes:
		c.a *= 0.45
	CombatFX.spawn_ring(parent, pos, c, radius)
	var ghost := Node2D.new()
	ghost.global_position = pos
	parent.add_child(ghost)
	var poly := Polygon2D.new()
	poly.color = Color(c.r, c.g, c.b, 0.18 if not GameState.reduce_flashes else 0.08)
	var pts := PackedVector2Array()
	for i in 14:
		pts.append(Vector2.from_angle(TAU * float(i) / 14.0) * radius)
	poly.polygon = pts
	ghost.add_child(poly)
	var tw := ghost.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, dur * 0.9)
	tw.tween_callback(ghost.queue_free)


static func _ghost_lane(boss: Node, x: float, color: Color, dur: float) -> void:
	var parent: Node = boss.get_parent()
	if parent == null:
		return
	var vp: Vector2 = boss.get_viewport_rect().size
	var ghost := Node2D.new()
	ghost.global_position = Vector2(x, vp.y * 0.5)
	parent.add_child(ghost)
	var poly := Polygon2D.new()
	var a := 0.22 if not GameState.reduce_flashes else 0.09
	poly.color = Color(color.r, color.g, color.b, a)
	poly.polygon = PackedVector2Array([
		Vector2(-13, -vp.y * 0.5), Vector2(13, -vp.y * 0.5),
		Vector2(15, vp.y * 0.5), Vector2(-15, vp.y * 0.5),
	])
	ghost.add_child(poly)
	var inner := Polygon2D.new()
	inner.color = Color(1, 1, 1, 0.14 if not GameState.reduce_flashes else 0.06)
	inner.polygon = PackedVector2Array([
		Vector2(-2, -vp.y * 0.5), Vector2(2, -vp.y * 0.5),
		Vector2(2, vp.y * 0.5), Vector2(-2, vp.y * 0.5),
	])
	ghost.add_child(inner)
	var tw := ghost.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, dur)
	tw.parallel().tween_property(inner, "modulate:a", 0.0, dur * 0.85)
	tw.tween_callback(ghost.queue_free)


static func _ghost_cross(boss: Node, pos: Vector2, color: Color, dur: float) -> void:
	var parent: Node = boss.get_parent()
	if parent == null:
		return
	_ghost_ring(boss, pos, color, 16.0, dur)
	for dir in [Vector2(0, 1), Vector2(0.72, 0.72), Vector2(-0.72, 0.72), Vector2(0.92, 0.34), Vector2(-0.92, 0.34)]:
		var n := Node2D.new()
		n.global_position = pos
		parent.add_child(n)
		var poly := Polygon2D.new()
		poly.color = Color(color.r, color.g, color.b, 0.20 if not GameState.reduce_flashes else 0.08)
		var s := 3.0
		poly.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		n.add_child(poly)
		var tw := n.create_tween()
		tw.tween_property(n, "global_position", pos + dir * 42.0, dur * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(poly, "modulate:a", 0.0, dur)
		tw.tween_callback(n.queue_free)


static func _flare_telegraph(boss: Node, dur: float) -> void:
	var tree: SceneTree = boss.get_tree()
	if tree == null:
		return
	var root: Node = tree.root
	var vp: Vector2 = boss.get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 6
	root.add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 0.55, 0.2, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_top = vp.y * 0.55
	layer.add_child(rect)
	var peak := 0.22 if GameState.reduce_flashes else 0.58
	var tw := layer.create_tween()
	tw.tween_property(rect, "color:a", peak * 0.35, 0.15)
	tw.tween_interval(dur - 0.60)
	tw.tween_property(rect, "color:a", peak, 0.12)
	tw.tween_interval(0.10)
	tw.tween_property(rect, "color:a", 0.0, 0.32)
	tw.tween_callback(layer.queue_free)


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
			spiral_shot(boss, muzzle, spd, dmg, 0.68 if phase % 2 == 0 else -0.68, {"lifetime": 2.6})
			if phase >= 1:
				helix_pair(boss, muzzle, spd * 0.9, dmg)
			boss.set("_fire_timer", stats.fire_interval * (1.10 - 0.05 * float(phase)))
		ARCH_DRILL:
			spread_fan(boss, muzzle, spd * 0.85, dmg, 3, 0.70)
			if phase >= 1:
				_ghost_ring(boss, muzzle, Color(0.75, 0.55, 0.35), 14.0, 0.55)
				_set_lock(boss, 0.35)
				var d_col: Vector2 = muzzle
				var d_spd: float = spd
				var d_dmg: float = dmg
				boss.get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if not is_instance_valid(boss) or boss.get("alive") == false:
						return
					arc_shot(boss, d_col, d_spd * 0.9, d_dmg, 0.52, {"lifetime": 2.6})
				)
			boss.set("_fire_timer", stats.fire_interval * 1.12)
		ARCH_OVERSEER:
			helix_pair(boss, muzzle, spd * 0.92, dmg)
			if phase >= 1:
				spiral_burst(boss, muzzle, spd * 0.70, dmg, 4, 0.52, {"scale": 0.85, "lifetime": 2.6})
			boss.set("_fire_timer", stats.fire_interval * 1.10)
		ARCH_ACE:
			arc_shot(boss, muzzle, spd * 1.0, dmg, 0.60, {"lifetime": 2.6})
			arc_shot(boss, muzzle, spd * 1.0, dmg, -0.60, {"lifetime": 2.6})
			if phase >= 1:
				spiral_shot(boss, muzzle, spd * 0.95, dmg, 0.62, {"lifetime": 2.6})
			boss.set("_fire_timer", stats.fire_interval * 1.08)
		ARCH_STORM:
			spiral_burst(boss, muzzle, spd * 0.75, dmg, 5, 0.58, {"scale": 0.9, "lifetime": 2.6})
			if phase >= 1:
				helix_pair(boss, muzzle, spd * 0.88, dmg)
			boss.set("_fire_timer", stats.fire_interval * 1.12)
		ARCH_TRANSPORT:
			_fire_transport(boss, phase, muzzle, spd, dmg, stats)
		ARCH_PRISM:
			_fire_prism(boss, phase, muzzle, spd, dmg, stats)
		ARCH_COIL:
			_fire_coil(boss, phase, muzzle, spd, dmg, stats)
		ARCH_ECHO:
			_fire_echo(boss, phase, muzzle, spd, dmg, stats)
		ARCH_TYRANT:
			spread_fan(boss, muzzle, spd * 0.72, dmg, 3, 0.75, {"scale": 1.2, "lifetime": 3.6, "color": Color(0.95, 0.55, 0.3)})
			if phase >= 1:
				arc_shot(boss, muzzle, spd * 0.78, dmg, 0.55, {"scale": 1.1, "lifetime": 2.6})
			boss.set("_fire_timer", stats.fire_interval * 1.14)
		ARCH_HERALD:
			spiral_burst(boss, muzzle, spd * 0.82, dmg, 4, 0.55, {"color": Color(1.0, 0.65, 0.3), "scale": 1.0, "lifetime": 2.6})
			if phase >= 1:
				arc_shot(boss, muzzle, spd * 0.95, dmg, -0.52, {"lifetime": 2.6})
			boss.set("_fire_timer", stats.fire_interval * 1.10)
		_:
			spiral_burst(boss, muzzle, spd * 0.80, dmg, 3, 0.52, {"scale": 0.9, "lifetime": 2.6})
			boss.set("_fire_timer", stats.fire_interval * 1.14)


static func _fire_orbital(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var arms := 3 if phase == 0 else 4
	var base: float = boss.get("_armor_angle")
	var vulnerable := absf(sin(base)) > 0.65
	if vulnerable:
		EventBus.gimmick_toast.emit("ARMOR GAP")
	for i in arms:
		var a := base + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a) * 0.85, 0.55 + 0.35 * absf(cos(a))).normalized()
		var o := {"lifetime": 2.6, "scale": 1.05 if vulnerable else 0.95}
		spawn_shot(boss, muzzle, dir * spd, dmg, o)
	if vulnerable:
		_ghost_ring(boss, muzzle, Color(0.45, 0.85, 1.0), 22.0, 0.55)
		_set_lock(boss, 0.45)
	if phase >= 1:
		spiral_shot(boss, muzzle, spd * 0.9, dmg, 0.62 if phase == 1 else -0.62, {"lifetime": 2.6})
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.72, dmg, 5, 0.62, {"scale": 0.85, "lifetime": 2.6})
	boss.set("_fire_timer", stats.fire_interval * (1.12 - 0.07 * float(phase)))


static func _fire_megalith(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var count := 4 if phase == 0 else 5
	spread_fan(boss, muzzle, spd * 0.72, dmg, count, 0.85, {"scale": 1.3, "lifetime": 4.0})
	if phase >= 1:
		for side in [-1.0, 1.0]:
			var wing := muzzle + Vector2(side * 38.0, 6.0)
			_ghost_ring(boss, wing, Color(0.75, 0.55, 0.4), 12.0, 0.60)
			_set_lock(boss, 0.40)
			var p_muzzle: Vector2 = muzzle
			var p_spd: float = spd
			var p_dmg: float = dmg
			boss.get_tree().create_timer(0.55).timeout.connect(func() -> void:
				if not is_instance_valid(boss) or boss.get("alive") == false:
					return
				for s in [-1.0, 1.0]:
					arc_shot(boss, p_muzzle + Vector2(s * 38.0, 6.0), p_spd * 0.82, p_dmg, s * 0.52, {"scale": 1.05, "lifetime": 2.6})
			)
	if phase >= 2:
		spiral_burst(boss, muzzle, spd * 0.65, dmg, 5, 0.52, {"scale": 0.9, "lifetime": 2.6})
	boss.set("_fire_timer", stats.fire_interval * (1.18 - 0.08 * float(phase)))


static func _fire_leviathan(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	var count := 3 if phase == 0 else 4
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var a := lerpf(-0.5, 0.5, t)
		var dir := Vector2(a, 1).normalized()
		var o := {
			"color": Color(0.85, 0.45, 1.0),
			"scale": 0.9,
			"lifetime": 2.6,
		}
		spawn_shot(boss, muzzle, dir * spd * 0.9, dmg, o)
	if phase >= 1:
		spiral_burst(boss, muzzle + Vector2(0, 8), spd * 0.58, dmg * 0.55, 4, 0.0, {
			"color": Color(0.7, 0.35, 0.95, 0.32),
			"scale": 0.62,
			"lifetime": 3.2,
		})
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (1.08 - 0.06 * float(phase)))


static func _fire_fabrication(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float) -> void:
	if phase == 0:
		helix_pair(boss, muzzle, spd * 0.95, dmg)
		_ghost_cross(boss, muzzle, Color(0.5, 1.0, 0.7), 0.60)
		_set_lock(boss, 0.40)
		var f_muzzle: Vector2 = muzzle
		var f_spd: float = spd
		var f_dmg: float = dmg
		boss.get_tree().create_timer(0.55).timeout.connect(func() -> void:
			if not is_instance_valid(boss) or boss.get("alive") == false:
				return
			cross(boss, f_muzzle, f_spd * 0.88, f_dmg, {"scale": 0.9, "lifetime": 2.6})
		)
	else:
		spiral_burst(boss, muzzle, spd * 0.75, dmg, 4, 0.52, {"scale": 0.9, "lifetime": 2.6})
		helix_pair(boss, muzzle, spd * 0.9, dmg)
		if phase >= 2:
			_ghost_cross(boss, muzzle, Color(0.5, 1.0, 0.75), 0.60)
			_set_lock(boss, 0.38)
			var f2_muzzle: Vector2 = muzzle
			var f2_spd: float = spd
			var f2_dmg: float = dmg
			boss.get_tree().create_timer(0.50).timeout.connect(func() -> void:
				if not is_instance_valid(boss) or boss.get("alive") == false:
					return
				cross(boss, f2_muzzle, f2_spd * 0.82, f2_dmg, {"lifetime": 2.6})
			)
	boss.set("_fire_timer", (boss.get("stats") as EnemyStats).fire_interval * (1.14 - 0.07 * float(phase)))


static func _fire_omega(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	EventBus.gimmick_toast.emit("OMEGA RING")
	_ghost_ring(boss, muzzle, Color(1.0, 0.35, 0.55), 28.0, 0.60)
	_set_lock(boss, 0.42)
	var o_muzzle: Vector2 = muzzle
	var o_spd: float = spd
	var o_dmg: float = dmg
	var o_phase: int = phase
	var o_t: float = boss.get("_t")
	boss.get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		var count := 6 if o_phase == 0 else 7
		for i in count:
			if i % 3 == 2:
				continue
			var a := TAU * float(i) / float(count) + o_t * 0.5
			var dir := Vector2(sin(a), cos(a) * 0.45 + 0.65).normalized()
			var o := {"scale": 0.9, "lifetime": 2.6}
			spawn_shot(boss, o_muzzle, dir * o_spd * (0.72 if o_phase == 0 else 0.68), o_dmg, o)
	)
	if phase == 0:
		helix_pair(boss, muzzle, spd * 0.92, dmg)
	else:
		aimed(boss, muzzle, spd * 1.0, dmg, 1, 0.0, {"lifetime": 2.6})
		if o_phase >= 1:
			spiral_shot(boss, muzzle + Vector2(22, 0), spd * 0.95, dmg, 0.68, {"lifetime": 2.6})
			spiral_shot(boss, muzzle + Vector2(-22, 0), spd * 0.95, dmg, -0.68, {"lifetime": 2.6})
		if o_phase >= 2:
			arc_shot(boss, muzzle, spd * 0.88, dmg, 0.60, {"scale": 1.0, "lifetime": 2.6})
			arc_shot(boss, muzzle, spd * 0.88, dmg, -0.60, {"scale": 1.0, "lifetime": 2.6})
	boss.set("_fire_timer", stats.fire_interval * (0.95 - 0.06 * float(phase)))


static func _fire_kaleidoscope(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var rot: float = boss.get("_armor_angle")
	var arms := 5 if phase == 0 else 6
	var vuln := absf(cos(rot)) > 0.72
	if vuln:
		EventBus.gimmick_toast.emit("PRISM GAP")
	_ghost_ring(boss, muzzle, Color(0.45, 0.9, 1.0), 20.0, 0.50)
	_set_lock(boss, 0.38)
	var k_muzzle: Vector2 = muzzle
	var k_spd: float = spd
	var k_dmg: float = dmg
	var k_rot: float = rot
	var k_arms: int = arms
	boss.get_tree().create_timer(0.48).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		for i in k_arms:
			var a := k_rot + TAU * float(i) / float(k_arms)
			var dir := Vector2(sin(a), absf(cos(a)) * 0.4 + 0.6).normalized()
			var o := {"color": Color(0.45, 0.9, 1.0), "scale": 0.9, "lifetime": 2.6}
			spawn_shot(boss, k_muzzle, dir * k_spd, k_dmg, o)
	)
	if phase >= 1:
		spiral_burst(boss, muzzle, spd * 0.78, dmg, 4, 0.58, {"color": Color(0.7, 0.95, 1.0), "scale": 0.82, "lifetime": 2.6})
	if phase >= 2:
		helix_pair(boss, muzzle, spd * 0.88, dmg)
	boss.set("_fire_timer", stats.fire_interval * (1.08 - 0.06 * float(phase)))


static func _fire_tempest(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	var cols: Array = [-64.0, 64.0] if phase == 0 else [-78.0, 0.0, 78.0]
	for col in cols:
		_ghost_lane(boss, muzzle.x + float(col), Color(0.4, 0.85, 1.0), 0.70)
	_set_lock(boss, 0.50)
	EventBus.gimmick_toast.emit("ION STRIKE")
	if GameState.shake_intensity > 0.01:
		EventBus.screen_shake.emit(3.5, 0.12)
	var t_muzzle: Vector2 = muzzle
	var t_spd: float = spd
	var t_dmg: float = dmg
	var t_cols: Array = cols.duplicate()
	var t_phase: int = phase
	boss.get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		for c in t_cols:
			var origin := t_muzzle + Vector2(float(c), 0)
			arc_shot(boss, origin, t_spd * 0.92, t_dmg, 0.0, {"color": Color(0.4, 0.85, 1.0), "scale": 0.78, "lifetime": 2.4})
			if t_phase >= 2 and float(c) != 0.0:
				arc_shot(boss, origin + Vector2(0, -12), t_spd * 0.88, t_dmg, 0.0, {"color": Color(0.55, 0.9, 1.0), "scale": 0.72, "lifetime": 2.4})
	)
	if phase >= 1:
		helix_pair(boss, muzzle, spd * 0.9, dmg)
	boss.set("_fire_timer", stats.fire_interval * (1.06 - 0.05 * float(phase)))


static func _fire_choir(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spiral_burst(boss, muzzle, spd * 0.76, dmg, 4, 0.54, {"color": Color(0.45, 0.55, 1.0), "scale": 0.92, "lifetime": 2.6})
	helix_pair(boss, muzzle, spd * 0.88, dmg)
	var tree: SceneTree = boss.get_tree()
	if tree:
		var echo_muzzle := muzzle
		var echo_spd := spd
		var echo_dmg := dmg
		var echo_phase := phase
		var player := tree.get_first_node_in_group("player") as Node2D
		var ghost_pos := echo_muzzle
		if player and is_instance_valid(player):
			ghost_pos = player.global_position
		_ghost_ring(boss, ghost_pos, Color(0.4, 0.5, 1.0), 18.0, 0.55)
		EventBus.gimmick_toast.emit("ECHO")
		_set_lock(boss, 0.35)
		tree.create_timer(0.52).timeout.connect(func() -> void:
			if not is_instance_valid(boss) or boss.get("alive") == false:
				return
			var base := echo_muzzle
			var use_ghost := ghost_pos
			var dir := (use_ghost - base).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2(0, 1)
			var spread := 0.35
			for i in 3:
				var a := lerpf(-spread, spread, float(i) / 2.0)
				spawn_shot(boss, base, dir.rotated(a) * echo_spd * 0.62, echo_dmg * 0.65, {
					"color": Color(0.4, 0.5, 1.0, 0.45),
					"scale": 0.68,
					"lifetime": 2.6,
				})
			spiral_burst(boss, use_ghost, echo_spd * 0.58, echo_dmg * 0.55, 3 + echo_phase, 0.0, {
				"color": Color(0.4, 0.5, 1.0, 0.38),
				"scale": 0.62,
				"lifetime": 2.6,
			})
		)
	boss.set("_fire_timer", stats.fire_interval * (1.18 - 0.06 * float(phase)))


static func _fire_junkyard(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	for off in [-48.0, 48.0]:
		_ghost_lane(boss, muzzle.x + off, Color(0.9, 0.5, 0.28), 0.60)
	EventBus.gimmick_toast.emit("SCRAP LANE")
	_set_lock(boss, 0.42)
	var j_muzzle: Vector2 = muzzle
	var j_spd: float = spd
	var j_dmg: float = dmg
	var j_phase: int = phase
	boss.get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		spread_fan(boss, j_muzzle, j_spd * 0.68, j_dmg, 3, 0.75, {"scale": 1.2, "lifetime": 3.8, "color": Color(0.9, 0.5, 0.28)})
		for i in 2:
			var dir := 1.0 if i == 0 else -1.0
			arc_shot(boss, j_muzzle + Vector2(dir * 32.0, 4.0), j_spd * randf_range(0.55, 0.75), j_dmg, dir * 0.42, {"scale": randf_range(0.95, 1.3), "color": Color(0.75, 0.45, 0.25), "lifetime": 2.6})
		if j_phase >= 2:
			spiral_burst(boss, j_muzzle, j_spd * 0.62, j_dmg, 4, 0.52, {"color": Color(1.0, 0.55, 0.3), "scale": 0.85, "lifetime": 2.6})
		var player := boss.get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var push := 110.0 if randf() > 0.5 else -110.0
			if player.has_method("get"):
				player.set("scrap_push", push)
				boss.get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if is_instance_valid(player) and player.get("scrap_push") == push:
						player.set("scrap_push", 0.0)
				)
	)
	boss.set("_fire_timer", stats.fire_interval * (1.18 - 0.06 * float(phase)))


static func _fire_dawn(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	_flare_telegraph(boss, 0.75)
	EventBus.gimmick_toast.emit("SOLAR FLARE")
	if GameState.shake_intensity > 0.01:
		EventBus.screen_shake.emit(5.0, 0.16)
	_ghost_ring(boss, muzzle, Color(1.0, 0.55, 0.25), 26.0, 0.70)
	_set_lock(boss, 0.50)
	var d_muzzle: Vector2 = muzzle
	var d_spd: float = spd
	var d_dmg: float = dmg
	var d_phase: int = phase
	boss.get_tree().create_timer(0.68).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		var count := 5 + d_phase * 2
		for i in count:
			if d_phase >= 1 and (i == 1 or i == count - 2):
				continue
			var a := lerpf(-0.70, 0.70, float(i) / float(maxi(count - 1, 1)))
			spawn_shot(boss, d_muzzle, Vector2(a, 1).normalized() * d_spd * 0.74, d_dmg, {"scale": 1.15, "color": Color(1.0, 0.55, 0.25), "lifetime": 2.6})
		if d_phase >= 1:
			helix_pair(boss, d_muzzle, d_spd * 0.92, d_dmg)
			for s in [-1.0, 1.0]:
				arc_shot(boss, d_muzzle + Vector2(s * 44.0, 8.0), d_spd * 0.88, d_dmg, s * 0.48, {"color": Color(1.0, 0.7, 0.3), "scale": 1.0, "lifetime": 2.6})
		if d_phase >= 2:
			spiral_burst(boss, d_muzzle, d_spd * 0.62, d_dmg, 5, 0.58, {"color": Color(1.0, 0.6, 0.2), "scale": 0.82, "lifetime": 2.6})
	)
	boss.set("_fire_timer", stats.fire_interval * (1.06 - 0.06 * float(phase)))


static func _fire_transport(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	for side in [-1.0, 1.0]:
		var wing := muzzle + Vector2(side * 38.0, 10.0)
		_ghost_ring(boss, wing, Color(0.55, 0.8, 1.0), 10.0, 0.45)
	_set_lock(boss, 0.30)
	var t_muzzle: Vector2 = muzzle
	var t_spd: float = spd
	var t_dmg: float = dmg
	boss.get_tree().create_timer(0.42).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		for s in [-1.0, 1.0]:
			var wing := t_muzzle + Vector2(s * 38.0, 10.0)
			arc_shot(boss, wing, t_spd * 0.88, t_dmg, s * 0.58, {"scale": 1.1, "color": Color(0.55, 0.8, 1.0), "lifetime": 2.6})
	)
	spiral_burst(boss, muzzle, spd * 0.75, dmg, 3, 0.48, {"scale": 0.85, "lifetime": 2.6})
	boss.set("_fire_timer", stats.fire_interval * (1.12 - 0.05 * float(phase)))


static func _fire_prism(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	for dir in [Vector2(0.95, 0.32), Vector2(-0.95, 0.32)]:
		_ghost_ring(boss, muzzle + dir * 18.0, Color(0.5, 0.9, 1.0), 9.0, 0.45)
	_set_lock(boss, 0.32)
	var p_muzzle: Vector2 = muzzle
	var p_spd: float = spd
	var p_dmg: float = dmg
	boss.get_tree().create_timer(0.40).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		for d in [Vector2(0.95, 0.32), Vector2(-0.95, 0.32)]:
			var o := {"color": Color(0.5, 0.9, 1.0), "scale": 0.9, "lifetime": 2.6}
			spawn_shot(boss, p_muzzle, d.normalized() * p_spd, p_dmg, o)
	)
	helix_pair(boss, muzzle, spd * 0.92, dmg)
	boss.set("_fire_timer", stats.fire_interval * 1.12)


static func _fire_coil(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	spiral_burst(boss, muzzle, spd * 0.72, dmg, 5, 0.52, {"color": Color(0.4, 0.85, 1.0), "scale": 0.8, "lifetime": 2.6})
	for side in [-1.0, 1.0]:
		_ghost_lane(boss, muzzle.x + side * 50.0, Color(0.55, 0.9, 1.0), 0.55)
	_set_lock(boss, 0.38)
	var c_muzzle: Vector2 = muzzle
	var c_spd: float = spd
	var c_dmg: float = dmg
	boss.get_tree().create_timer(0.48).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		for s in [-1.0, 1.0]:
			arc_shot(boss, c_muzzle + Vector2(s * 50.0, 0), c_spd * 1.05, c_dmg, s * 0.52, {"color": Color(0.55, 0.9, 1.0), "scale": 1.0, "lifetime": 2.6})
	)
	boss.set("_fire_timer", stats.fire_interval * 1.10)


static func _fire_echo(boss: Node, phase: int, muzzle: Vector2, spd: float, dmg: float, stats: EnemyStats) -> void:
	helix_pair(boss, muzzle, spd, dmg)
	var echo_pos := muzzle
	var player := boss.get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		echo_pos = player.global_position
	_ghost_ring(boss, echo_pos, Color(0.4, 0.55, 1.0), 16.0, 0.50)
	_set_lock(boss, 0.35)
	var e_muzzle: Vector2 = muzzle
	var e_spd: float = spd
	var e_dmg: float = dmg
	var e_phase: int = phase
	boss.get_tree().create_timer(0.48).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or boss.get("alive") == false:
			return
		spiral_shot(boss, e_muzzle, e_spd * 0.9, e_dmg, 0.58 if e_phase == 0 else -0.58, {"color": Color(0.4, 0.55, 1.0, 0.5), "scale": 0.75, "lifetime": 2.6})
	)
	boss.set("_fire_timer", stats.fire_interval * 1.10)


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

	var lock: float = float(boss.get("_telegraph_lock")) if boss.get("_telegraph_lock") != null else 0.0
	if lock > 0.0:
		lock = maxf(0.0, lock - delta)
		boss.set("_telegraph_lock", lock)

	if arch == ARCH_STALKER:
		var cd: float = boss.get("_teleport_cd")
		cd -= delta
		if cd <= 0.0:
			cd = randf_range(3.4, 5.0)
			var vp: Vector2 = boss.get_viewport_rect().size
			var dest := Vector2(randf_range(80.0, vp.x - 80.0), randf_range(80.0, 200.0))
			_ghost_ring(boss, boss.global_position, Color(0.7, 0.4, 1.0), 20.0, 0.35)
			boss.get_tree().create_timer(0.32).timeout.connect(func() -> void:
				if not is_instance_valid(boss) or boss.get("alive") == false:
					return
				boss.global_position = dest
				boss.set("_origin_x", dest.x)
				_ghost_ring(boss, dest, Color(0.7, 0.4, 1.0), 22.0, 0.35)
			)
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
		if lock > 0.0:
			boss.global_position.y = target_y + sin(t * 0.9) * 2.0
		elif arch == ARCH_LEVIATHAN:
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


static func spiral_shot(boss: Node, muzzle: Vector2, spd: float, dmg: float, _curve: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	var player := boss.get_tree().get_first_node_in_group("player") if boss.get_tree() else null
	var aim := Vector2(0, 1)
	if player is Node2D and is_instance_valid(player):
		aim = ((player as Node2D).global_position - muzzle).normalized()
		if aim.y < 0.15:
			aim.y = 0.15
			aim = aim.normalized()
	spawn_shot(boss, muzzle, aim * spd, dmg, o)


static func arc_shot(boss: Node, muzzle: Vector2, spd: float, dmg: float, _curve: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	spawn_shot(boss, muzzle, Vector2(0, 1) * spd, dmg, o)


static func helix_pair(boss: Node, muzzle: Vector2, spd: float, dmg: float, opts: Dictionary = {}) -> void:
	var o1 := opts.duplicate()
	var o2 := opts.duplicate()
	spawn_shot(boss, muzzle + Vector2(-8, 0), Vector2(-0.18, 1).normalized() * spd, dmg, o1)
	spawn_shot(boss, muzzle + Vector2(8, 0), Vector2(0.18, 1).normalized() * spd, dmg, o2)


static func spiral_burst(boss: Node, muzzle: Vector2, spd: float, dmg: float, count: int, _curve: float, opts: Dictionary = {}) -> void:
	var t_rot: float = boss.get("_t")
	for i in count:
		var a := TAU * float(i) / float(count) + t_rot * 0.5
		var dir := Vector2(sin(a), cos(a) * 0.45 + 0.65).normalized()
		var o := opts.duplicate()
		spawn_shot(boss, muzzle, dir * spd, dmg, o)
