extends Area2D
## Electrical bridge spanning a barrier gap — shoot the gap to break the connection.
## Barrier segments themselves remain solid; only this bridge is destroyable.

var hp: float = 6.0
var scroll_speed: float = 50.0
var _alive: bool = true
var _barriers: Array[Node] = []

@onready var _poly: Polygon2D = $Polygon2D
@onready var _glow: Polygon2D = $Glow
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _solid: CollisionShape2D = $Solid/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("barrier_conductors")
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func setup(from: Vector2, to: Vector2, scroll: float, left_barrier: Node, right_barrier: Node) -> void:
	scroll_speed = scroll * 1.15
	_barriers = [left_barrier, right_barrier]
	var mid := (from + to) * 0.5
	global_position = mid
	var width := absf(to.x - from.x)
	var height := 10.0
	if _poly:
		_poly.polygon = PackedVector2Array([
			Vector2(-width * 0.5, -height * 0.5),
			Vector2(width * 0.5, -height * 0.5),
			Vector2(width * 0.5, height * 0.5),
			Vector2(-width * 0.5, height * 0.5),
		])
		_poly.color = Color(0.85, 0.95, 1.0, 0.92)
	if _glow:
		_glow.polygon = PackedVector2Array([
			Vector2(-width * 0.5 - 4.0, -height * 0.5 - 6.0),
			Vector2(width * 0.5 + 4.0, -height * 0.5 - 6.0),
			Vector2(width * 0.5 + 4.0, height * 0.5 + 6.0),
			Vector2(-width * 0.5 - 4.0, height * 0.5 + 6.0),
		])
		_glow.color = Color(0.45, 0.75, 1.0, 0.28)
	if _collision and _collision.shape is RectangleShape2D:
		(_collision.shape as RectangleShape2D).size = Vector2(maxf(width, 12.0), height)
	if _solid and _solid.shape is RectangleShape2D:
		(_solid.shape as RectangleShape2D).size = Vector2(maxf(width, 12.0), height)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	global_position.y += scroll_speed * delta
	# Flicker electrical arc
	if _poly:
		var t := Time.get_ticks_msec() * 0.012
		_poly.modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * sin(t * 3.7))
		_poly.skew = sin(t * 5.1) * 0.08
	if global_position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func take_damage(amount: float, _armor_pierce: bool = false) -> void:
	if not _alive:
		return
	hp -= amount
	_flash()
	if hp <= 0.0:
		_die()


func _flash() -> void:
	if _poly:
		_poly.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.05).timeout.connect(func() -> void:
			if is_instance_valid(self) and _alive and _poly:
				_poly.modulate = Color.WHITE
		)


func _die() -> void:
	if not _alive:
		return
	_alive = false
	GameState.add_score(250)
	AudioBus.play_explode()
	EventBus.gimmick_toast.emit("CONNECTION SEVERED")
	EventBus.screen_shake.emit(3.0, 0.12)
	if get_parent():
		CombatFX.spawn_burst(get_parent(), global_position, Color(0.55, 0.85, 1.0), 8, 22.0)
	# Barriers remain permanently solid — only the bridge is removed, opening the gap
	monitoring = false
	monitorable = false
	visible = false
	if _solid:
		_solid.set_deferred("disabled", true)
	# Keep node for a moment then free so scroll doesn't need to handle
	await get_tree().create_timer(0.1).timeout
	queue_free()


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)


func _on_area(area: Area2D) -> void:
	# Bullets are handled via take_damage, not here
	pass
