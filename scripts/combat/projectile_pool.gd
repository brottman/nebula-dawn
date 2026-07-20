class_name ProjectilePool
extends Node
## Simple object pool for player and enemy projectiles.

@export var player_projectile_scene: PackedScene
@export var enemy_projectile_scene: PackedScene
@export var initial_size: int = 32

var _player_pool: Array[Node] = []
var _enemy_pool: Array[Node] = []
var _container: Node2D


func setup(container: Node2D) -> void:
	_container = container
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
	return _spawn(_enemy_pool, enemy_projectile_scene, pos, velocity, damage, false, opts)


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
