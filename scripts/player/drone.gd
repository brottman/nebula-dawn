class_name Drone
extends Node2D
## Orbiting drone — auto-fires a single aimed shot at the nearest enemy
## every few seconds. Max 2; one is lost on each hit taken.

const ORBIT_RADIUS := 38.0
const ORBIT_SPEED := 2.4
const FIRE_INTERVAL := 3.0
const SHOT_SPEED := 420.0
const SHOT_DAMAGE := 0.6

var host: Node2D
var projectile_pool: ProjectilePool
var slot: int = 0 ## 0 = clockwise orbit, 1 = counter-clockwise
var _angle: float = 0.0
var _fire_timer: float = 1.5
var _poly: Polygon2D


func setup(owner_ship: Node2D, pool: ProjectilePool, drone_slot: int) -> void:
	host = owner_ship
	projectile_pool = pool
	slot = drone_slot
	_angle = PI * 0.5 + (PI if drone_slot == 0 else 0.0)
	_build_visual()


func _build_visual() -> void:
	_poly = Polygon2D.new()
	_poly.color = Color(1.0, 0.85, 0.4, 0.95)
	_poly.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(5, 5), Vector2(0, 2), Vector2(-5, 5)
	])
	add_child(_poly)


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	_angle += ORBIT_SPEED * delta * (1.0 if slot == 0 else -1.0)
	var offset := Vector2(cos(_angle), sin(_angle)) * ORBIT_RADIUS
	# Prefer side stations slightly aft of the nose.
	offset.y += 4.0
	global_position = host.global_position + offset
	rotation = offset.angle() + PI * 0.5
	if bool(host.get("secondaries_disabled")):
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = FIRE_INTERVAL
	_fire_at_enemy()


func _fire_at_enemy() -> void:
	if projectile_pool == null:
		return
	var target: Node2D = _nearest_enemy()
	if target == null:
		return
	var origin := global_position + Vector2(0, -6)
	var dir := (target.global_position - origin).normalized()
	var dmg := SHOT_DAMAGE * float(host.get("damage_mult"))
	projectile_pool.spawn_player(origin, dir * SHOT_SPEED, dmg, {
		"scale": 0.7, "color": Color(1.0, 0.8, 0.35), "lifetime": 2.4})


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or n is not Node2D:
			continue
		if n.get("alive") == false:
			continue
		var d2 := global_position.distance_squared_to((n as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n as Node2D
	return best
