extends Area2D
## Plasma / obscure zone that drifts with the playfield scroll.

var scroll_speed: float = 45.0


func _ready() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	global_position.y += scroll_speed * delta
	if global_position.y > get_viewport_rect().size.y + 80.0:
		queue_free()
