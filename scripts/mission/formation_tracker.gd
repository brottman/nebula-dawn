extends Node
## Tracks formation membership for Stage 1 chain-reaction clears.

var _members: Dictionary = {} # formation_id -> Array[Node]
var _centers: Dictionary = {} # formation_id -> Vector2
var projectile_pool: ProjectilePool


func _ready() -> void:
	add_to_group("formation_tracker")


func setup(pool: ProjectilePool) -> void:
	projectile_pool = pool
	_members.clear()
	_centers.clear()


func register(enemy: Node, formation_id: String) -> void:
	if formation_id == "" or enemy == null:
		return
	if not _members.has(formation_id):
		_members[formation_id] = []
	(_members[formation_id] as Array).append(enemy)
	if enemy is Node2D:
		_centers[formation_id] = (enemy as Node2D).global_position


func notify_killed(enemy: Node2D, formation_id: String) -> void:
	if formation_id == "" or enemy == null:
		return
	_centers[formation_id] = enemy.global_position
	if not _members.has(formation_id):
		return
	var arr: Array = _members[formation_id]
	arr.erase(enemy)
	if arr.is_empty():
		_members.erase(formation_id)
		var center: Vector2 = _centers.get(formation_id, enemy.global_position)
		_centers.erase(formation_id)
		_trigger_chain(center)


func _trigger_chain(center: Vector2) -> void:
	EventBus.formation_cleared.emit(center, 0)
	EventBus.screen_shake.emit(5.0, 0.12)
	EventBus.gimmick_toast.emit("CHAIN REACTION!")
	if projectile_pool:
		projectile_pool.clear_enemy_in_radius(center, 130.0)
	GameState.add_score(250)
	# Occasional bonus drop — not every formation clear.
	if randf() < 0.35:
		_spawn_bonus(center)


func _spawn_bonus(pos: Vector2) -> void:
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var entities := parent.get_node_or_null("Entities")
	var host: Node = entities if entities else parent
	var p: Node = scene.instantiate()
	host.add_child(p)
	p.global_position = pos
	if p.has_method("setup"):
		p.setup("power" if randf() < 0.55 else "option")
