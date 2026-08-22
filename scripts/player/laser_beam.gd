extends Node2D
## Continuous piercing column from the ship nose to the top of the playfield.
## Damage is applied as DPS while a target overlaps the beam.

const GLOW_COLOR := Color(0.25, 0.7, 1.0, 0.22)
const MID_COLOR := Color(0.45, 0.85, 1.0, 0.72)
const CORE_COLOR := Color(0.92, 0.98, 1.0, 0.95)
const FLARE_COLOR := Color(0.75, 0.95, 1.0, 0.9)
const HIT_SPARK := Color(0.7, 0.95, 1.0)

var _glow: Polygon2D
var _mid: Polygon2D
var _core: Polygon2D
var _flare: Polygon2D
var _age: float = 0.0
var _hit_sfx_cd: float = 0.0
var _spark_cd: Dictionary = {}
var _melt_cd: Dictionary = {}
var _level: int = 1


func _ready() -> void:
	z_as_relative = false
	z_index = 8
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _make_poly(GLOW_COLOR, add)
	_mid = _make_poly(MID_COLOR, add)
	_core = _make_poly(CORE_COLOR, add)
	_flare = _make_poly(FLARE_COLOR, add)
	visible = false
	set_process(false)


func _make_poly(color: Color, mat: CanvasItemMaterial) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.material = mat
	add_child(poly)
	return poly


func extinguish() -> void:
	visible = false
	set_process(false)
	_spark_cd.clear()
	_melt_cd.clear()


func fire(delta: float, origin: Vector2, half_width: float, dps: float, armor_pierce: bool, melt_dps: float, cancel_bullets: bool, level: int = 1) -> void:
	global_position = origin
	_level = clampi(level, 1, 5)
	_age += delta
	if _hit_sfx_cd > 0.0:
		_hit_sfx_cd -= delta
	_prune_cd(_spark_cd)
	_prune_cd(_melt_cd)
	var length := origin.y + 48.0
	_draw_beam(half_width, length)
	visible = true
	set_process(true)
	var struck := _strike_targets(delta, origin, half_width, dps, armor_pierce, melt_dps)
	if cancel_bullets:
		_eat_bullets(origin, half_width)
	if struck and _hit_sfx_cd <= 0.0:
		_hit_sfx_cd = 0.09
		AudioBus.play_hit()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Higher levels pulse brighter and faster — Lv1 gentle, Lv5 intense white-hot.
	var lvl_factor := clampf(float(_level - 1) / 4.0, 0.0, 1.0)
	var pulse_amp := 0.10 + 0.14 * lvl_factor
	var pulse_base := 0.88 + 0.07 * lvl_factor
	var pulse_speed := 28.0 + 14.0 * lvl_factor
	var pulse := pulse_base + pulse_amp * sin(_age * pulse_speed)
	# Overall brightness lifts with level (Lv5 ~1.25x)
	var bright := 1.0 + 0.28 * lvl_factor
	modulate = Color(bright, bright, bright, pulse)


func _draw_beam(half_width: float, length: float) -> void:
	var lvl_factor := clampf(float(_level - 1) / 4.0, 0.0, 1.0)
	# Lv1 thin/flickery, Lv5 thick/stable and intense
	var flicker := 1.0 + (0.10 - 0.06 * lvl_factor) * sin(_age * (32.0 + 14.0 * lvl_factor))
	var top := -length
	# Glow grows disproportionately — Lv5 has huge soft aura
	var glow_scale := 1.9 + 0.95 * lvl_factor
	var mid_scale := 1.08 + 0.22 * lvl_factor
	var core_scale := 0.28 + 0.14 * lvl_factor
	_set_rect(_glow, half_width * glow_scale * flicker, top)
	_set_rect(_mid, half_width * mid_scale * flicker, top)
	_set_rect(_core, maxf(1.4, half_width * core_scale), top)
	# Per-level color/alpha shift — thin blue at Lv1 → white-hot at Lv5
	var glow_alpha := 0.15 + 0.16 * lvl_factor
	var mid_alpha := 0.58 + 0.18 * lvl_factor
	_glow.color = Color(0.25, 0.7, 1.0, glow_alpha)
	_mid.color = Color(0.45 + 0.18 * lvl_factor, 0.85 + 0.06 * lvl_factor, 1.0, mid_alpha)
	_core.color = Color(0.92 + 0.07 * lvl_factor, 0.98, 1.0, 0.88 + 0.08 * lvl_factor)
	var flare_w := half_width * (1.35 + 0.45 * lvl_factor)
	var flare_h := 18.0 + 8.0 * lvl_factor
	_flare.color = Color(0.75, 0.95, 1.0, 0.55 + 0.35 * lvl_factor)
	_flare.polygon = PackedVector2Array([
		Vector2(0.0, 6.0),
		Vector2(flare_w, -10.0),
		Vector2(0.0, -flare_h),
		Vector2(-flare_w, -10.0),
	])


func _set_rect(poly: Polygon2D, half_w: float, top: float) -> void:
	poly.polygon = PackedVector2Array([
		Vector2(-half_w, 2.0),
		Vector2(half_w, 2.0),
		Vector2(half_w, top),
		Vector2(-half_w, top),
	])


func _strike_targets(delta: float, origin: Vector2, half_width: float, dps: float, armor_pierce: bool, melt_dps: float) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var amount := dps * delta
	if amount <= 0.0:
		return false
	var hit := false
	for node in tree.get_nodes_in_group("enemies"):
		if _try_hit_node(node, origin, half_width, amount, armor_pierce, melt_dps):
			hit = true
	for node in tree.get_nodes_in_group("hazards"):
		if node != null and node.is_in_group("barriers"):
			continue
		if _try_hit_node(node, origin, half_width, amount, armor_pierce, melt_dps):
			hit = true
	return hit


func _try_hit_node(node: Node, origin: Vector2, half_width: float, amount: float, armor_pierce: bool, melt_dps: float) -> bool:
	if node == null or not is_instance_valid(node) or node is not Node2D:
		return false
	if node.get("alive") == false:
		return false
	if not node.has_method("take_damage"):
		return false
	var target := node as Node2D
	if not _overlaps(target, origin, half_width):
		return false
	target.take_damage(amount, armor_pierce)
	if melt_dps > 0.0 and target.has_method("apply_melt"):
		var id := target.get_instance_id()
		if float(_melt_cd.get(id, 0.0)) <= _age:
			_melt_cd[id] = _age + 0.18
			target.apply_melt(5, melt_dps)
	_spark_at(target)
	return true


func _eat_bullets(origin: Vector2, half_width: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemy_projectiles"):
		if node == null or not is_instance_valid(node) or node is not Node2D:
			continue
		var shot := node as Node2D
		if absf(shot.global_position.x - origin.x) > half_width + 6.0:
			continue
		if shot.global_position.y > origin.y:
			continue
		if shot.has_method("deactivate"):
			shot.deactivate()
		elif shot.has_method("queue_free"):
			shot.queue_free()


func _overlaps(node: Node2D, origin: Vector2, half_width: float) -> bool:
	var pos := node.global_position
	if pos.y > origin.y - 2.0:
		return false
	var half := _half_size(node)
	if pos.y + half.y < -40.0:
		return false
	return absf(pos.x - origin.x) <= half_width + half.x


func _half_size(node: Node2D) -> Vector2:
	var stats: Variant = node.get("stats")
	if stats != null and stats.get("size") != null:
		return Vector2(stats.size) * 0.5
	return Vector2(16.0, 16.0)


func _spark_at(target: Node2D) -> void:
	var id := target.get_instance_id()
	if float(_spark_cd.get(id, 0.0)) > _age:
		return
	_spark_cd[id] = _age + 0.07
	var parent := target.get_parent()
	if parent == null:
		return
	var pos := target.global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-8.0, 6.0))
	CombatFX.spawn_hit_spark(parent, pos, HIT_SPARK)


func _prune_cd(bag: Dictionary) -> void:
	if bag.size() < 24:
		return
	var stale: Array = []
	for id in bag.keys():
		if float(bag[id]) + 1.0 < _age:
			stale.append(id)
	for id in stale:
		bag.erase(id)
