class_name ProjectilePool
extends Node
## Simple object pool for player and enemy projectiles.

@export var player_projectile_scene: PackedScene
@export var enemy_projectile_scene: PackedScene
@export var initial_size: int = 32

const MIN_ACTIVE_ENEMY_PROJECTILES := 32
const MAX_ACTIVE_ENEMY_PROJECTILES := 64

var _player_pool: Array[Node] = []
var _enemy_pool: Array[Node] = []
var _container: Node2D
var _enemy_projectile_cap: int = MAX_ACTIVE_ENEMY_PROJECTILES


func setup(container: Node2D) -> void:
	_container = container
	_enemy_projectile_cap = MAX_ACTIVE_ENEMY_PROJECTILES
	_warm(_player_pool, player_projectile_scene, initial_size)
	_warm(_enemy_pool, enemy_projectile_scene, initial_size)


func _warm(pool: Array[Node], scene: PackedScene, count: int) -> void:
	if scene == null:
		return
	for i in count:
		var proj := scene.instantiate()
		proj.visible = false
		proj.set_process(false)
		proj.set_physics_process(false)
		_container.add_child(proj)
		if proj.has_method("deactivate"):
			proj.deactivate()
		pool.append(proj)


func spawn_player(pos: Vector2, velocity: Vector2, damage: float = 1.0, opts: Dictionary = {}) -> Node:
	return _spawn(_player_pool, player_projectile_scene, pos, velocity, damage, true, opts)


func spawn_enemy(pos: Vector2, velocity: Vector2, damage: float = 1.0, opts: Dictionary = {}) -> Node:
	_trim_enemy_projectiles()
	return _spawn(_enemy_pool, enemy_projectile_scene, pos, velocity, damage, false, opts)


func set_enemy_projectile_pressure(pressure: float) -> void:
	## The intensity director narrows this cap when the player is struggling.
	_enemy_projectile_cap = clampi(
		int(roundf(lerpf(
			float(MIN_ACTIVE_ENEMY_PROJECTILES),
			float(MAX_ACTIVE_ENEMY_PROJECTILES),
			clampf(pressure, 0.0, 1.0)
		))),
		MIN_ACTIVE_ENEMY_PROJECTILES,
		MAX_ACTIVE_ENEMY_PROJECTILES
	)


## Cancel enemy bullets inside a radius (formation chain-reaction / terminal reward).
func clear_enemy_in_radius(center: Vector2, radius: float) -> int:
	var cleared := 0
	var r2 := radius * radius
	for p in _enemy_pool:
		if p == null or not p.has_method("is_active") or not p.is_active():
			continue
		if p.global_position.distance_squared_to(center) <= r2:
			if p.has_method("deactivate"):
				p.deactivate()
				cleared += 1
	return cleared


func get_active_enemy_projectiles() -> Array[Node]:
	var out: Array[Node] = []
	for p in _enemy_pool:
		if p != null and p.has_method("is_active") and p.is_active():
			out.append(p)
	return out


func _trim_enemy_projectiles() -> void:
	var active := get_active_enemy_projectiles()
	if active.size() < _enemy_projectile_cap:
		return
	var oldest: Node = active[0]
	var oldest_age := float(oldest.get_age()) if oldest.has_method("get_age") else 0.0
	for projectile in active:
		if not projectile.has_method("get_age"):
			continue
		var age := float(projectile.get_age())
		if age > oldest_age:
			oldest = projectile
			oldest_age = age
	if oldest.has_method("deactivate"):
		oldest.deactivate()


func _spawn(pool: Array[Node], scene: PackedScene, pos: Vector2, velocity: Vector2, damage: float, from_player: bool, opts: Dictionary) -> Node:
	var proj: Node = null
	for p in pool:
		if p.has_method("is_active") and not p.is_active():
			proj = p
			break
	if proj == null:
		if scene == null:
			return null
		proj = scene.instantiate()
		_container.add_child(proj)
		pool.append(proj)
	if proj.has_method("activate"):
		proj.activate(pos, velocity, damage, from_player, opts)
	return proj
