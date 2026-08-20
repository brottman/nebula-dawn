extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 2-5: solar flare wash across the lower field + residual wells.

var _flare_overlay: ColorRect


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("DAWN FLARES")


func tick(_delta: float) -> void:
	super.tick(_delta)
	if pulse <= 0.0:
		pulse = rng.randf_range(7.5, 11.0)
		_trigger_flare()
		if rng.randf() < 0.45:
			spawn_singularity()


func cleanup() -> void:
	if _flare_overlay and is_instance_valid(_flare_overlay):
		var layer := _flare_overlay.get_parent()
		_flare_overlay.queue_free()
		_flare_overlay = null
		if layer and is_instance_valid(layer):
			layer.queue_free()
	super.cleanup()


func _trigger_flare() -> void:
	var vp := vp_size()
	EventBus.gimmick_toast.emit("SOLAR FLARE")
	EventBus.screen_shake.emit(7.0, 0.2)
	if _flare_overlay == null or not is_instance_valid(_flare_overlay):
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_flare_overlay = ColorRect.new()
		_flare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flare_overlay.color = Color(1.0, 0.55, 0.2, 0.0)
		layer.add_child(_flare_overlay)
	_flare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flare_overlay.offset_top = vp.y * 0.55
	var zone := Area2D.new()
	zone.collision_layer = 32
	zone.collision_mask = 1
	zone.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(vp.x, vp.y * 0.45)
	shape.shape = rect
	zone.add_child(shape)
	entities.add_child(zone)
	track(zone)
	zone.global_position = Vector2(vp.x * 0.5, vp.y * 0.78)
	zone.monitoring = false
	zone.monitorable = false
	zone.body_entered.connect(_on_flare_hit)
	var preview_alpha := 0.08 if GameState.reduce_flashes else 0.18
	var peak_alpha := 0.22 if GameState.reduce_flashes else 0.62
	var tw := create_tween()
	tw.tween_property(_flare_overlay, "color:a", preview_alpha, 0.15)
	tw.tween_interval(0.55)
	tw.tween_property(_flare_overlay, "color:a", peak_alpha, 0.12)
	tw.tween_callback(func() -> void:
		zone.monitoring = true
		zone.monitorable = true
		if pool and pool.has_method("clear_enemy_in_radius"):
			pool.clear_enemy_in_radius(Vector2(vp.x * 0.5, vp.y * 0.25), vp.x * 0.7)
	)
	tw.tween_interval(0.85)
	tw.tween_property(_flare_overlay, "color:a", 0.0, 0.35)
	tw.tween_callback(_expire_flare.bind(zone))


func _on_flare_hit(b: Node) -> void:
	if b.is_in_group("player") and b.has_method("take_damage"):
		b.take_damage(1)


func _expire_flare(zone: Node) -> void:
	if is_instance_valid(zone):
		zone.queue_free()
