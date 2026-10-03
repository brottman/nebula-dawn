extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 2-4: horizontal scrap conveyors that shove the ship.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("SCRAP CONVEYORS")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0:
		pulse = rng.randf_range(5.0, 7.5)
		_spawn_scrap_belt()


func _spawn_scrap_belt() -> void:
	if entities == null:
		return
	var vp := vp_size()
	var dir := 1.0 if rng.randf() > 0.5 else -1.0
	var y := rng.randf_range(vp.y * 0.35, vp.y * 0.75)
	var belt := Area2D.new()
	belt.collision_layer = 0
	belt.collision_mask = 1
	belt.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(vp.x + 40.0, 54.0)
	shape.shape = rect
	belt.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.85, 0.55, 0.25, 0.22)
	poly.polygon = PackedVector2Array([
		Vector2(-vp.x * 0.5, -24), Vector2(vp.x * 0.5, -24),
		Vector2(vp.x * 0.5, 24), Vector2(-vp.x * 0.5, 24)
	])
	belt.add_child(poly)
	for i in 5:
		var chev := Polygon2D.new()
		chev.color = Color(1.0, 0.75, 0.35, 0.55)
		var sx := dir * 10.0
		chev.polygon = PackedVector2Array([Vector2(-sx, -8), Vector2(sx, 0), Vector2(-sx, 8)])
		chev.position = Vector2((-2 + i) * 70.0, 0)
		poly.add_child(chev)
	entities.add_child(belt)
	track(belt)
	belt.global_position = Vector2(vp.x * 0.5, y)
	var push := dir * 160.0
	belt.body_entered.connect(_on_scrap_entered.bind(push))
	belt.body_exited.connect(_on_scrap_exited)
	var life := belt.create_tween()
	life.tween_interval(4.5)
	life.tween_callback(_on_scrap_expired.bind(belt))


func _on_scrap_entered(b: Node, push: float) -> void:
	if b.is_in_group("player"):
		b.set("scrap_push", push)
		EventBus.gimmick_toast.emit("CONVEYOR")


func _on_scrap_exited(b: Node) -> void:
	if b.is_in_group("player"):
		b.set("scrap_push", 0.0)


func _on_scrap_expired(belt: Node) -> void:
	if player and is_instance_valid(player):
		player.set("scrap_push", 0.0)
	if is_instance_valid(belt):
		belt.queue_free()
