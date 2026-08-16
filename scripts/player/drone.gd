class_name Drone
extends Node2D
## Wingman drone — fixed side/rear gunner mounted on the player ship.
## Slot 0 = port wing (fires left), 1 = starboard wing (fires right),
## 2 = rear gunner (fires down behind the ship). Max 3; one lost per hit.

const FIRE_INTERVAL := 2.2
const SHOT_SPEED := 380.0
const SHOT_DAMAGE := 0.6

const MAX_BANK := 0.3
const BANK_RATE := 8.0

const SLOT_OFFSETS := {
	0: Vector2(-28.0, 8.0),
	1: Vector2(28.0, 8.0),
	2: Vector2(0.0, 22.0),
}
const SLOT_ROTATION := {
	0: -PI * 0.5, # faces left
	1: PI * 0.5, # faces right
	2: PI, # faces down (rear gunner)
}
const SLOT_DIR := {
	0: Vector2.LEFT,
	1: Vector2.RIGHT,
	2: Vector2.DOWN,
}

var host: Node2D
var projectile_pool: ProjectilePool
var slot: int = 0 ## 0 = port, 1 = starboard, 2 = rear
var _fire_timer: float = 1.5
var _bank: float = 0.0
var _sprite: Sprite2D
var _poly: Polygon2D


func setup(owner_ship: Node2D, pool: ProjectilePool, drone_slot: int) -> void:
	host = owner_ship
	projectile_pool = pool
	slot = drone_slot
	_fire_timer = 1.0 + float(slot) * 0.4
	_build_visual()


func _build_visual() -> void:
	var tex := load("res://assets/sprites/drone.svg") as Texture2D
	if tex:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.texture_filter = TextureFilter.TEXTURE_FILTER_LINEAR
		_sprite.scale = Vector2.ONE * 0.6
		add_child(_sprite)
	else:
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
	global_position = host.global_position + SLOT_OFFSETS.get(slot, Vector2(0.0, 20.0))
	var host_speed: float = float(host.get("move_speed")) if host.has_method("get") else 310.0
	var host_vx: float = 0.0
	var raw_vx: Variant = host.get("bank_vx") if host.has_method("get") else null
	if raw_vx != null:
		host_vx = float(raw_vx)
	elif host is CharacterBody2D:
		host_vx = (host as CharacterBody2D).velocity.x
	var bank_target := clampf(host_vx / maxf(host_speed, 1.0), -1.0, 1.0) * MAX_BANK
	_bank = lerpf(_bank, bank_target, 1.0 - exp(-BANK_RATE * delta))
	rotation = float(SLOT_ROTATION.get(slot, 0.0)) + _bank
	if bool(host.get("secondaries_disabled")):
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = FIRE_INTERVAL
	_fire_salvo()


func _fire_salvo() -> void:
	if projectile_pool == null:
		return
	var dir: Vector2 = SLOT_DIR.get(slot, Vector2.DOWN)
	var dmg := SHOT_DAMAGE * float(host.get("damage_mult"))
	var origin := global_position + dir * 4.0
	for i in 3:
		var d := dir.rotated((float(i) - 1.0) * 0.12)
		projectile_pool.spawn_player(origin, d * SHOT_SPEED, dmg, {
			"scale": 0.7, "color": Color(1.0, 0.8, 0.35), "lifetime": 2.4})
