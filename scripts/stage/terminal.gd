extends Area2D
## Shootable terminal — disables nearby barriers and clears enemy bullets.

var hp: float = 8.0
var scroll_speed: float = 40.0
var projectile_pool: ProjectilePool
var alive: bool = true

@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("terminals")
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


func setup(pool: ProjectilePool, scroll: float) -> void:
	projectile_pool = pool
	scroll_speed = scroll * 0.85


func _physics_process(delta: float) -> void:
	if not alive:
		return
	global_position.y += scroll_speed * delta
	if global_position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_poly.modulate = Color(2, 2, 2)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_poly.modulate = Color.WHITE
	)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	GameState.add_score(400)
	AudioBus.play_explode()
	EventBus.gimmick_toast.emit("TERMINAL OFFLINE")
	EventBus.screen_shake.emit(4.0, 0.1)
	if projectile_pool:
		projectile_pool.clear_enemy_in_radius(global_position, 160.0)
	for b in get_tree().get_nodes_in_group("barriers"):
		if b.has_method("disable_temporarily") and global_position.distance_to(b.global_position) < 280.0:
			b.disable_temporarily(4.0)
	queue_free()


func _on_hit(_other: Node) -> void:
	pass
