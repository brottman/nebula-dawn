class_name CombatFX
extends RefCounted
## Lightweight one-shot VFX helpers (no scenes required).


static func spawn_burst(parent: Node, pos: Vector2, color: Color = Color(1.0, 0.7, 0.35), count: int = 10, radius: float = 28.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.z_as_relative = false
	root.z_index = 40
	root.global_position = pos
	parent.add_child(root)
	for i in count:
		var spark := Polygon2D.new()
		var s := randf_range(1.6, 3.4)
		spark.polygon = PackedVector2Array([
			Vector2(-s, -s * 0.4), Vector2(s, 0), Vector2(-s, s * 0.4)
		])
		spark.color = color.lightened(randf_range(-0.1, 0.25))
		spark.rotation = randf() * TAU
		root.add_child(spark)
		var dir := Vector2.from_angle(TAU * float(i) / float(count) + randf_range(-0.2, 0.2))
		var dist := radius * randf_range(0.55, 1.15)
		var tw := root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", dir * dist, randf_range(0.18, 0.32)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, randf_range(0.2, 0.35)).set_delay(0.05)
		tw.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.3)
	var life := root.create_tween()
	life.tween_interval(0.4)
	life.tween_callback(root.queue_free)


static func spawn_ring(parent: Node, pos: Vector2, color: Color = Color(1.0, 0.85, 0.5), radius: float = 18.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var ring := Polygon2D.new()
	ring.z_as_relative = false
	ring.z_index = 39
	ring.global_position = pos
	ring.color = Color(color.r, color.g, color.b, 0.85)
	var pts := PackedVector2Array()
	const SEGMENTS := 14
	for i in SEGMENTS:
		pts.append(Vector2.from_angle(TAU * float(i) / float(SEGMENTS)) * radius)
	ring.polygon = pts
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)


static func spawn_hit_spark(parent: Node, pos: Vector2, color: Color = Color(1.0, 1.0, 0.85)) -> void:
	spawn_burst(parent, pos, color, 5, 12.0)
