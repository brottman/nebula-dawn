extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 2-2: vertical lightning columns.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("ION STORM")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0:
		pulse = rng.randf_range(3.2, 5.2)
		_spawn_ion_column()


func _spawn_ion_column() -> void:
	if entities == null:
		return
	var vp := vp_size()
	var x := rng.randf_range(50.0, vp.x - 50.0)
	var bolt := Area2D.new()
	bolt.collision_layer = 32
	bolt.collision_mask = 1
	bolt.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, vp.y)
	shape.shape = rect
	bolt.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.55, 0.85, 1.0, 0.45)
	poly.polygon = PackedVector2Array([
		Vector2(-10, -vp.y * 0.5), Vector2(10, -vp.y * 0.5),
		Vector2(14, vp.y * 0.5), Vector2(-14, vp.y * 0.5)
	])
	bolt.add_child(poly)
	entities.add_child(bolt)
	track(bolt)
	bolt.global_position = Vector2(x, vp.y * 0.5)
	EventBus.gimmick_toast.emit("ION STRIKE")
	EventBus.screen_shake.emit(4.0, 0.1)
	bolt.body_entered.connect(_on_ion_hit)
	var tw := bolt.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, 0.55)
	tw.tween_callback(bolt.queue_free)


func _on_ion_hit(b: Node) -> void:
	if b.is_in_group("player") and b.has_method("take_damage"):
		b.take_damage(1)
