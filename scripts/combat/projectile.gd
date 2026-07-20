extends Area2D
## Pooled bullet used by both sides.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var from_player: bool = true
var _active: bool = false
var _lifetime: float = 3.0
var _age: float = 0.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	deactivate()


func is_active() -> bool:
	return _active


func activate(pos: Vector2, vel: Vector2, dmg: float, player_shot: bool) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	from_player = player_shot
	_active = true
	_age = 0.0
	visible = true
	set_process(true)
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if _collision:
		_collision.set_deferred("disabled", false)
	# Layers: 1=player, 2=player_proj, 3=enemy, 4=enemy_proj, 5=pickup, 6=hazard
	if from_player:
		collision_layer = 2
		collision_mask = 4 | 32
		if _poly:
			_poly.color = Color(0.55, 0.9, 1.0)
	else:
		collision_layer = 8
		collision_mask = 1
		if _poly:
			_poly.color = Color(1.0, 0.55, 0.35)


func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _collision:
		_collision.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += velocity * delta
	_age += delta
	var vp := get_viewport_rect().size
	if _age > _lifetime or global_position.y < -40.0 or global_position.y > vp.y + 40.0 \
			or global_position.x < -40.0 or global_position.x > vp.x + 40.0:
		deactivate()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	if not _active:
		return
	if from_player:
		if (target.is_in_group("enemies") or target.is_in_group("hazards")) and target.has_method("take_damage"):
			target.take_damage(damage)
			AudioBus.play_hit()
			deactivate()
	else:
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(int(damage))
			deactivate()
