extends Area2D
## Gravity well — pulls the player / bullets and fills Overdrive on graze.

var pull_strength: float = 140.0
var _life: float = 8.0
var _player: Node
var _pool: ProjectilePool
var _graze_cd: float = 0.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _ring: Polygon2D = $GrazeRing
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _graze: Area2D = $GrazeSensor


func _ready() -> void:
	add_to_group("singularities")
	collision_layer = 0
	collision_mask = 0
	if _graze:
		_graze.collision_layer = 0
		_graze.collision_mask = 8
		_graze.area_entered.connect(_on_graze)


func setup(player: Node, proj_pool: ProjectilePool = null) -> void:
	_player = player
	_pool = proj_pool
	_draw_visuals()


func _draw_visuals() -> void:
	if _poly:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 28.0)
		_poly.polygon = pts
		_poly.color = Color(0.15, 0.05, 0.25, 0.85)
	if _ring:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a), sin(a)) * 70.0)
		_ring.polygon = pts
		_ring.color = Color(0.7, 0.4, 1.0, 0.12)


func _physics_process(delta: float) -> void:
	_life -= delta
	_graze_cd = maxf(0.0, _graze_cd - delta)
	rotation += delta * 1.2
	_apply_pull(delta)
	if _life <= 0.0:
		queue_free()


func _apply_pull(delta: float) -> void:
	var center := global_position
	if _pool:
		for proj in _pool.get_active_enemy_projectiles():
			var to: Vector2 = center - proj.global_position
			var d2: float = to.length_squared()
			if d2 < 40.0 or d2 > 200.0 * 200.0:
				continue
			var pull: Vector2 = to.normalized() * (pull_strength * 50.0 / d2) * delta * 3200.0
			if "velocity" in proj:
				proj.velocity += pull
	if _player and is_instance_valid(_player) and _player.get("dead") != true:
		var to_p: Vector2 = center - _player.global_position
		var pd2: float = to_p.length_squared()
		if pd2 > 36.0 and pd2 < 180.0 * 180.0:
			_player.global_position += to_p.normalized() * (70.0 / sqrt(pd2)) * delta * 32.0


func _on_graze(area: Area2D) -> void:
	if _graze_cd > 0.0:
		return
	if area.get("from_player") == true:
		return
	if not area.has_method("is_active") or not area.is_active():
		return
	_graze_cd = 0.08
	if _player and _player.has_method("add_overdrive"):
		_player.add_overdrive(6.0)
	EventBus.gimmick_toast.emit("GRAZE")