extends Area2D
## Gravity well — pulls the player / bullets and fills Overdrive on graze.

var pull_strength: float = 140.0
var _life: float = 8.0
var _player: Node
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


func setup(player: Node) -> void:
	_player = player
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
	if _life <= 0.0:
		queue_free()


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
