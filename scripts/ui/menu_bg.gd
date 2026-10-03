extends Node2D
## Attract-mode backdrop for the title screen: deep-space gradient, breathing
## nebula glows, a three-speed starfield, and enemy silhouettes diving down
## the screen to suggest live combat behind the menu.

const SHIP_TINTS := [
	Color(0.95, 0.45, 0.3),
	Color(0.75, 0.3, 0.85),
	Color(0.3, 0.65, 0.95),
]

var _stars: Array[Vector3] = []       ## x, y, depth (0 = near, 1 = far)
var _nebulae: Array[Dictionary] = []  ## pos, radius, tint, phase
var _ships: Array[Dictionary] = []    ## pos, speed, size, sway, phase, tint
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rebuild()
	get_viewport().size_changed.connect(_rebuild)


func _rebuild() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	_stars.clear()
	_nebulae.clear()
	_ships.clear()
	for i in 110:
		_stars.append(Vector3(_rng.randf() * vp.x, _rng.randf() * vp.y, _rng.randf()))
	for i in 5:
		_nebulae.append({
			"pos": Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y),
			"radius": _rng.randf_range(120.0, 260.0),
			"tint": _rng.randf(),
			"phase": _rng.randf() * TAU,
		})
	for i in 6:
		_ships.append(_new_ship(vp, _rng.randf() * vp.y))


func _new_ship(vp: Vector2, y: float) -> Dictionary:
	return {
		"pos": Vector2(_rng.randf_range(30.0, vp.x - 30.0), y),
		"speed": _rng.randf_range(14.0, 26.0),
		"size": _rng.randf_range(7.0, 12.0),
		"sway": _rng.randf_range(10.0, 26.0),
		"phase": _rng.randf() * TAU,
		"tint": SHIP_TINTS[_rng.randi() % SHIP_TINTS.size()],
	}


func _process(delta: float) -> void:
	_time += delta
	var vp := get_viewport_rect().size
	for i in _stars.size():
		var s := _stars[i]
		s.y += delta * (10.0 + s.z * 26.0)
		if s.y > vp.y + 2.0:
			s.y = -2.0
			s.x = _rng.randf() * vp.x
		_stars[i] = s
	for i in _ships.size():
		var ship: Dictionary = _ships[i]
		var pos: Vector2 = ship["pos"]
		pos.y += float(ship["speed"]) * delta
		if pos.y > vp.y + 30.0:
			_ships[i] = _new_ship(vp, -30.0 - _rng.randf_range(0.0, 90.0))
		else:
			ship["pos"] = pos
			_ships[i] = ship
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	# Deep-space gradient base.
	for i in 8:
		var t := float(i) / 7.0
		var c := Color(0.05, 0.06, 0.14).lerp(Color(0.02, 0.02, 0.07), t)
		draw_rect(Rect2(0.0, vp.y * i / 8.0, vp.x, vp.y / 8.0 + 1.0), c)
	# Breathing nebula glows.
	for n in _nebulae:
		var pulse := 0.5 + 0.5 * sin(_time * 0.35 + float(n["phase"]))
		var t: float = n["tint"]
		var col := Color(0.35 + t * 0.4, 0.25 + t * 0.15, 0.85 - t * 0.4)
		for ring in 3:
			var rr := float(n["radius"]) * (1.0 - ring * 0.3)
			var a := 0.03 + 0.03 * float(ring) * (0.6 + 0.4 * pulse)
			draw_circle(n["pos"], rr, Color(col.r, col.g, col.b, a))
	# Starfield (nearer stars larger and brighter).
	for s in _stars:
		var depth: float = s.z
		draw_circle(Vector2(s.x, s.y), 0.6 + depth * 0.9,
			Color(0.75, 0.82, 1.0, 0.5 - depth * 0.35))
	# Diving enemy silhouettes with engine glow.
	for ship in _ships:
		var pos: Vector2 = ship["pos"]
		var size: float = ship["size"]
		pos.x += sin(_time * 1.4 + float(ship["phase"])) * float(ship["sway"])
		var tint: Color = ship["tint"]
		var pts := PackedVector2Array([
			pos + Vector2(0.0, size),
			pos + Vector2(size * 0.75, -size * 0.6),
			pos + Vector2(0.0, -size * 0.18),
			pos + Vector2(-size * 0.75, -size * 0.6),
		])
		draw_colored_polygon(pts, Color(tint.r, tint.g, tint.b, 0.4))
		draw_circle(pos + Vector2(0.0, size * 0.85), size * 0.35,
			Color(1.0, 0.6, 0.3, 0.18))
