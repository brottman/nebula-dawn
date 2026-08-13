class_name StageGimmick
extends Node
## Base runtime module for a mission `gimmick_id`. StageDirector instantiates
## one of these per stage; formations / asteroids are toast-only subclasses.

var director: Node
var player: Node
var pool: ProjectilePool
var entities: Node2D
var mission: MissionData
var rng: RandomNumberGenerator
var pulse: float = 2.0
var timer: float = 0.0
var _runtime: Array[Node] = []


func bind(host: Node) -> void:
	director = host
	player = host.get("player")
	pool = host.get("pool") as ProjectilePool
	entities = host.get("entities") as Node2D
	mission = host.get("mission") as MissionData
	rng = host.get("rng") as RandomNumberGenerator
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func begin() -> void:
	pulse = 2.0
	timer = 0.0


func tick(delta: float) -> void:
	timer += delta
	pulse -= delta


func on_boss_spawned(_boss: Node) -> void:
	pass


func on_boss_defeated() -> void:
	pass


func cleanup() -> void:
	for n in _runtime:
		if is_instance_valid(n):
			n.queue_free()
	_runtime.clear()


func track(n: Node) -> Node:
	_runtime.append(n)
	return n


func scroll_speed() -> float:
	return mission.scroll_speed if mission else 50.0


func vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func spawn_singularity() -> Node:
	var scene: PackedScene = load("res://scenes/stage/singularity.tscn")
	if scene == null or entities == null:
		return null
	var s: Node = scene.instantiate()
	entities.add_child(s)
	track(s)
	var vp := vp_size()
	s.global_position = Vector2(rng.randf_range(100.0, vp.x - 100.0), vp.y * 0.35)
	if s.has_method("setup"):
		s.setup(player, pool)
	return s
