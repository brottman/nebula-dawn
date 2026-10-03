extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 1-3: fog overlay + drifting plasma pools.

var _fog: ColorRect


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("NEBULA ANOMALY")
	_ensure_fog()


func tick(delta: float) -> void:
	super.tick(delta)
	if _fog:
		var wave := 0.55 + 0.45 * sin(timer * 0.7)
		var amp := 0.10 if GameState.reduce_flashes else 0.22
		_fog.color.a = 0.08 + amp * wave
		var vp := vp_size()
		_fog.offset_top = vp.y * (0.45 + 0.08 * sin(timer * 0.5))
	if pulse <= 0.0:
		pulse = rng.randf_range(4.5, 7.0)
		_spawn_plasma_pool()


func cleanup() -> void:
	if _fog and is_instance_valid(_fog):
		var layer := _fog.get_parent()
		_fog.queue_free()
		_fog = null
		if layer and is_instance_valid(layer):
			layer.queue_free()
	super.cleanup()


func _ensure_fog() -> void:
	if _fog:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_fog = ColorRect.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.color = Color(0.45, 0.2, 0.55, 0.0)
	layer.add_child(_fog)


func _spawn_plasma_pool() -> void:
	if entities == null:
		return
	var zone_script: Script = load("res://scripts/stage/drifting_zone.gd")
	var zone := Area2D.new()
	zone.set_script(zone_script)
	zone.add_to_group("plasma_zones")
	zone.collision_layer = 0
	zone.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	zone.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.6, 1.0, 0.85, 0.35)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 48.0)
	poly.polygon = pts
	zone.add_child(poly)
	entities.add_child(zone)
	track(zone)
	zone.scroll_speed = scroll_speed() * 0.9
	var vp := vp_size()
	zone.global_position = Vector2(rng.randf_range(60.0, vp.x - 60.0), -40.0)
	zone.body_entered.connect(_on_plasma_entered)
	zone.body_exited.connect(_on_plasma_exited)


func _on_plasma_entered(b: Node) -> void:
	if b.is_in_group("player") and b.has_method("enter_plasma"):
		b.enter_plasma()


func _on_plasma_exited(b: Node) -> void:
	if b.is_in_group("player") and b.has_method("exit_plasma"):
		b.exit_plasma()
