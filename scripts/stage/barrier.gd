extends Area2D
## Sweeping energy barrier — damages the player, blocks bullets and the ship.
## Only the gap between a pair is passable; terminals shut a fence down briefly.

var scroll_speed: float = 50.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _solid_collision: CollisionShape2D = $Solid/CollisionShape2D


func _ready() -> void:
	add_to_group("hazards")
	add_to_group("barriers")
	collision_layer = 32
	collision_mask = 1 | 2 | 8
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func setup(from: Vector2, to: Vector2, scroll: float) -> void:
	scroll_speed = scroll * 1.15
	var mid := (from + to) * 0.5
	global_position = mid
	var width := absf(to.x - from.x)
	var height := 14.0
	if _poly:
		_poly.polygon = PackedVector2Array([
			Vector2(-width * 0.5, -height * 0.5),
			Vector2(width * 0.5, -height * 0.5),
			Vector2(width * 0.5, height * 0.5),
			Vector2(-width * 0.5, height * 0.5),
		])
		_poly.color = Color(1.0, 0.35, 0.55, 0.75)
	if _collision and _collision.shape is RectangleShape2D:
		(_collision.shape as RectangleShape2D).size = Vector2(maxf(width, 8.0), height)
	if _solid_collision and _solid_collision.shape is RectangleShape2D:
		(_solid_collision.shape as RectangleShape2D).size = Vector2(maxf(width, 8.0), height)


func get_solid_rect() -> Rect2:
	if _solid_collision == null or _solid_collision.shape is not RectangleShape2D:
		return Rect2()
	var r := (_solid_collision.shape as RectangleShape2D).size
	return Rect2(global_position - r * 0.5, r)


func disable_temporarily(seconds: float = 3.0) -> void:
	visible = false
	monitoring = false
	monitorable = false
	if _collision:
		_collision.set_deferred("disabled", true)
	if _solid_collision:
		_solid_collision.set_deferred("disabled", true)
	await get_tree().create_timer(seconds).timeout
	if not is_instance_valid(self):
		return
	visible = true
	monitoring = true
	monitorable = true
	if _collision:
		_collision.set_deferred("disabled", false)
	if _solid_collision:
		_solid_collision.set_deferred("disabled", false)


func _physics_process(delta: float) -> void:
	global_position.y += scroll_speed * delta
	if global_position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func absorb_bullet(_damage: float = 0.0) -> void:
	pass


func take_damage(_amount: float, _armor_pierce: bool = false) -> void:
	# Barriers are invulnerable; only terminals shut them down.
	pass


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)


func _on_area(area: Area2D) -> void:
	if area.has_method("deactivate") and area.get("from_player") != null:
		area.deactivate()
