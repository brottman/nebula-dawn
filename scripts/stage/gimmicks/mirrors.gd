extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 2-1: bouncing mirror plates.


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("MIRROR FIELD")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0:
		pulse = rng.randf_range(3.8, 6.0)
		_spawn_mirror_plate()


func _spawn_mirror_plate() -> void:
	if entities == null:
		return
	var plate := Area2D.new()
	plate.set_script(load("res://scripts/stage/mirror_plate.gd"))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 14)
	shape.shape = rect
	plate.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.55, 0.85, 1.0, 0.7)
	poly.polygon = PackedVector2Array([
		Vector2(-35, -7), Vector2(35, -7), Vector2(35, 7), Vector2(-35, 7)
	])
	plate.add_child(poly)
	entities.add_child(plate)
	track(plate)
	var vp := vp_size()
	plate.global_position = Vector2(rng.randf_range(70.0, vp.x - 70.0), -30.0)
	if plate.has_method("setup"):
		plate.setup(scroll_speed())