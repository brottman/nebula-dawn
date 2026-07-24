extends Area2D
## Sector 2 mirror plate — bounces enemy bullets sideways instead of absorbing them.

var scroll_speed: float = 50.0
var _bounces_left: int = 6


func _ready() -> void:
	add_to_group("mirrors")
	add_to_group("hazards")
	collision_layer = 32
	collision_mask = 8 ## enemy projectiles
	monitoring = true
	monitorable = true


func setup(scroll: float) -> void:
	scroll_speed = scroll


func _physics_process(delta: float) -> void:
	global_position.y += scroll_speed * delta
	if global_position.y > get_viewport_rect().size.y + 60.0:
		queue_free()


func reflect_shot(proj: Node) -> bool:
	if _bounces_left <= 0 or proj == null:
		return false
	if not ("velocity" in proj):
		return false
	_bounces_left -= 1
	var vel: Vector2 = proj.velocity
	vel.x *= -1.15
	vel.y = absf(vel.y) * 1.05
	proj.velocity = vel
	if proj.has_method("on_reflected"):
		proj.on_reflected()
	elif "global_position" in proj:
		# Keep wave path origin coherent after the bounce.
		if "_base_pos" in proj:
			proj._base_pos = proj.global_position
	modulate = Color(1.6, 1.8, 2.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)
	if _bounces_left <= 0:
		queue_free()
	return true
