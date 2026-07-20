extends Area2D
## Collectible power-up drifting downward.

var kind: String = "spread"
var fall_speed: float = 70.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	collision_layer = 16
	collision_mask = 1
	add_to_group("pickups")


func setup(k: String) -> void:
	kind = k
	match kind:
		"spread":
			_poly.color = Color(0.4, 1.0, 0.6)
			_label.text = "S"
		"railgun":
			_poly.color = Color(0.75, 1.0, 1.0)
			_label.text = "P"
		"homing":
			_poly.color = Color(1.0, 0.7, 0.25)
			_label.text = "H"
		"wave":
			_poly.color = Color(0.8, 0.5, 1.0)
			_label.text = "W"
		"flak":
			_poly.color = Color(1.0, 0.45, 0.35)
			_label.text = "F"
		"power":
			_poly.color = Color(1.0, 1.0, 0.85)
			_label.text = "^"
		"rapid":
			_poly.color = Color(1.0, 0.85, 0.3)
			_label.text = "R"
		"shield":
			_poly.color = Color(0.45, 0.75, 1.0)
			_label.text = "B"
		"heal":
			_poly.color = Color(1.0, 0.4, 0.55)
			_label.text = "+"
		_:
			_poly.color = Color.WHITE
			_label.text = "?"


func _physics_process(delta: float) -> void:
	global_position.y += fall_speed * delta
	rotation += delta
	if global_position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_collect(body)


func _on_area_entered(area: Area2D) -> void:
	_try_collect(area)


func _try_collect(target: Node) -> void:
	if target.is_in_group("player") and target.has_method("apply_pickup"):
		target.apply_pickup(kind)
		queue_free()
