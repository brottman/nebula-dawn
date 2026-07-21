class_name BitDrone
extends Node2D
## Orbiting option / bit — mirrors fire or seeks nearby threats.
## Stacks as a sub-system; does not replace the main weapon.

const ORBIT_RADIUS := 38.0
const ORBIT_SPEED := 2.4

var host: Node2D
var projectile_pool: ProjectilePool
var slot: int = 0 ## 0 = left, 1 = right
var seek: bool = false ## true = auto-target mode
var _angle: float = 0.0
var _poly: Polygon2D


func setup(owner_ship: Node2D, pool: ProjectilePool, bit_slot: int) -> void:
	host = owner_ship
	projectile_pool = pool
	slot = bit_slot
	seek = bit_slot == 1 ## second bit seeks; first mirrors forward
	_angle = PI * 0.5 + (PI if bit_slot == 0 else 0.0)
	_build_visual()


func _build_visual() -> void:
	_poly = Polygon2D.new()
	_poly.color = Color(0.55, 0.95, 1.0, 0.95) if not seek else Color(1.0, 0.85, 0.4, 0.95)
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


func fire(damage_mult: float = 1.0) -> void:
	if projectile_pool == null:
		return
	var origin := global_position + Vector2(0, -6)
	if seek:
		projectile_pool.spawn_player(origin, Vector2(0, -420.0), 0.65 * damage_mult, {
			"homing": 8.0, "scale": 0.75, "color": Color(1.0, 0.8, 0.35), "lifetime": 1.8})
	else:
		projectile_pool.spawn_player(origin, Vector2(0, -520.0), 0.55 * damage_mult, {
			"scale": 0.7, "color": Color(0.6, 0.95, 1.0), "lifetime": 1.4})
