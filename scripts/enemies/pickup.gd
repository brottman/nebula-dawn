extends Area2D
## Collectible power-up drifting downward.
## Color weapons: red=Spread, blue=Laser, green=Homing. Gold Power = shared level.

var kind: String = "spread"
var fall_speed: float = 70.0
## Volcano Power Orb — fractional levels restored on collect.
var orb_restore: float = 0.5
var _volcano: bool = false

const SPRITE_PATHS := {
	"spread": "res://assets/sprites/pickup_spread.svg",
	"vulcan": "res://assets/sprites/pickup_spread.svg",
	"red": "res://assets/sprites/pickup_spread.svg",
	"laser": "res://assets/sprites/pickup_laser.svg",
	"beam": "res://assets/sprites/pickup_laser.svg",
	"blue": "res://assets/sprites/pickup_laser.svg",
	"homing": "res://assets/sprites/pickup_homing.svg",
	"missiles": "res://assets/sprites/pickup_homing.svg",
	"green": "res://assets/sprites/pickup_homing.svg",
	"power": "res://assets/sprites/pickup_power.svg",
	"pchip": "res://assets/sprites/pickup_power.svg",
	"p-chip": "res://assets/sprites/pickup_power.svg",
	"gold": "res://assets/sprites/pickup_power.svg",
	"power_orb": "res://assets/sprites/pickup_power.svg",
	"orb": "res://assets/sprites/pickup_power.svg",
	"option": "res://assets/sprites/pickup_option.svg",
	"bit": "res://assets/sprites/pickup_option.svg",
	"drone": "res://assets/sprites/pickup_option.svg",
	"shield": "res://assets/sprites/pickup_shield.svg",
	"barrier": "res://assets/sprites/pickup_shield.svg",
	"bomb": "res://assets/sprites/pickup_bomb.svg",
	"cleaver": "res://assets/sprites/pickup_bomb.svg",
	"energy": "res://assets/sprites/pickup_heal.svg",
	"overdrive_pickup": "res://assets/sprites/pickup_heal.svg",
	"rapid": "res://assets/sprites/pickup_heal.svg",
	"heal": "res://assets/sprites/pickup_heal.svg",
}

const TOAST_NAMES := {
	"spread": "SPREAD",
	"vulcan": "SPREAD",
	"red": "SPREAD",
	"laser": "LASER",
	"beam": "LASER",
	"blue": "LASER",
	"homing": "HOMING",
	"missiles": "HOMING",
	"green": "HOMING",
	"power": "POWER",
	"pchip": "POWER",
	"p-chip": "POWER",
	"gold": "POWER",
	"power_orb": "POWER ORB",
	"orb": "POWER ORB",
	"option": "DRONE",
	"bit": "DRONE",
	"drone": "DRONE",
	"shield": "SHIELD",
	"barrier": "SHIELD",
	"bomb": "BOMB",
	"cleaver": "BOMB",
	"energy": "HEAL",
	"overdrive_pickup": "HEAL",
	"rapid": "HEAL",
	"heal": "HEAL",
}

@onready var _sprite: Sprite2D = $Sprite2D
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
	var path: String = SPRITE_PATHS.get(kind, "")
	var tex: Texture2D = load(path) if path != "" else null
	if _sprite and tex:
		_sprite.texture = tex
		_sprite.visible = true
		_sprite.scale = Vector2(1.35, 1.35) if _volcano or kind == "power_orb" else Vector2(0.9, 0.9)
		if _poly:
			_poly.visible = false
		if _label:
			# Colorblind aid: glyph over the sprite when enabled in settings.
			_label.visible = GameState.show_pickup_labels
			if _label.visible:
				_label.text = _glyph_for(kind)
				_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
				_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
				_label.add_theme_constant_override("outline_size", 4)
		return
	# Fallback polygons if a sprite is missing.
	if _poly:
		_poly.visible = true
	if _label:
		_label.visible = true
		_label.text = _glyph_for(kind)
	match kind:
		"spread", "vulcan", "red":
			_poly.color = Color(1.0, 0.28, 0.28)
		"laser", "beam", "blue":
			_poly.color = Color(0.35, 0.65, 1.0)
		"homing", "missiles", "green":
			_poly.color = Color(0.3, 0.95, 0.4)
		"power", "pchip", "p-chip", "gold", "power_orb", "orb":
			_poly.color = Color(1.0, 0.85, 0.25)
		"option", "bit", "drone":
			_poly.color = Color(0.55, 0.95, 1.0)
		"shield", "barrier":
			_poly.color = Color(0.45, 0.75, 1.0)
		"bomb", "cleaver":
			_poly.color = Color(1.0, 0.35, 0.45)
		"energy", "overdrive_pickup", "rapid", "heal":
			_poly.color = Color(1.0, 0.4, 0.55)
		_:
			_poly.color = Color.WHITE


func _glyph_for(k: String) -> String:
	match k:
		"spread", "vulcan", "red":
			return "R"
		"laser", "beam", "blue":
			return "L"
		"homing", "missiles", "green":
			return "H"
		"power", "pchip", "p-chip", "gold", "power_orb", "orb":
			return "P"
		"option", "bit", "drone":
			return "D"
		"shield", "barrier":
			return "S"
		"bomb", "cleaver":
			return "X"
		"energy", "overdrive_pickup", "rapid", "heal":
			return "+"
		_:
			return "?"


func set_volcano(enabled: bool = true) -> void:
	_volcano = enabled
	fall_speed = 38.0 if enabled else 70.0
	if _sprite and _sprite.visible:
		_sprite.scale = Vector2(1.45, 1.45) if enabled else Vector2(0.9, 0.9)


func _physics_process(delta: float) -> void:
	global_position.y += fall_speed * delta
	rotation += delta * (0.35 if _volcano else 0.6)
	# Gentle bob so icons stay readable while spinning.
	if _sprite and _sprite.visible:
		var base := 1.4 if _volcano or kind == "power_orb" else 0.88
		_sprite.scale = Vector2.ONE * (base + 0.06 * sin(Time.get_ticks_msec() * 0.008))
	if global_position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_collect(body)


func _on_area_entered(area: Area2D) -> void:
	_try_collect(area)


func _try_collect(target: Node) -> void:
	if not target.is_in_group("player"):
		return
	if kind == "power_orb" or kind == "orb":
		if target.has_method("apply_power_orb"):
			target.apply_power_orb(orb_restore)
			AudioBus.play_pickup()
			EventBus.pickup_collected.emit(kind)
			queue_free()
			return
	if target.has_method("apply_pickup"):
		target.apply_pickup(kind)
		queue_free()