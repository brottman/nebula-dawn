extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 1-4: sweeping laser barriers + shootable terminals.

var _barriers: Array[Node] = []


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("LASER CORRIDORS")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0 and get_tree().get_nodes_in_group("boss").is_empty():
		pulse = rng.randf_range(6.5, 10.0)
		_spawn_barrier_pair()
		if rng.randf() < 0.7:
			_spawn_terminal()


func on_boss_spawned(_boss: Node) -> void:
	_clear_barriers()
	pulse = 3.0


func on_boss_defeated() -> void:
	pulse = 3.0


func cleanup() -> void:
	_clear_barriers()
	super.cleanup()


func _clear_barriers() -> void:
	for b in _barriers:
		if is_instance_valid(b):
			b.queue_free()
	_barriers.clear()


func _spawn_barrier_pair() -> void:
	var scene: PackedScene = load("res://scenes/stage/barrier.tscn")
	if scene == null or entities == null:
		return
	var vp := vp_size()
	var gap_x := rng.randf_range(vp.x * 0.25, vp.x * 0.75)
	var gap_w := 120.0
	for side in [-1, 1]:
		var b: Node = scene.instantiate()
		entities.add_child(b)
		_barriers.append(b)
		if b.has_method("setup"):
			var x0 := 0.0 if side < 0 else gap_x + gap_w * 0.5
			var x1 := gap_x - gap_w * 0.5 if side < 0 else vp.x
			b.setup(Vector2(x0, -20.0), Vector2(x1, -20.0), scroll_speed())


func _spawn_terminal() -> void:
	var scene: PackedScene = load("res://scenes/stage/terminal.tscn")
	if scene == null or entities == null:
		return
	var t: Node = scene.instantiate()
	entities.add_child(t)
	track(t)
	var vp := vp_size()
	t.global_position = Vector2(rng.randf_range(80.0, vp.x - 80.0), -30.0)
	if t.has_method("setup"):
		t.setup(pool, scroll_speed())