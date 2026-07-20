extends Node2D
## Layered scrolling background: gradient sky, drifting nebula clouds,
## three parallax star layers (near stars twinkle), and a slow planet.

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _stars_far: Array[Vector2] = []
var _stars_mid: Array[Vector2] = []
var _stars_near: Array[Vector2] = []
## x, y, radius — soft tinted blobs drifting slower than any star layer.
var _clouds: Array[Vector3] = []
## One planet at a time; respawns far above the top after drifting off.
var _planet := {"pos": Vector2(340, 200), "r": 64.0, "shade": 0.5}
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var vp := get_viewport_rect().size
	for i in 70:
		_stars_far.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))
	for i in 45:
		_stars_mid.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))
	for i in 30:
		_stars_near.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))
	for i in 5:
		_clouds.append(Vector3(
			_rng.randf() * vp.x, _rng.randf() * vp.y, _rng.randf_range(90.0, 200.0)))
	_planet["pos"] = Vector2(_rng.randf_range(80.0, vp.x - 80.0), vp.y * 0.3)
	_planet["shade"] = _rng.randf()


func set_tint(c: Color) -> void:
	tint = c
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	_scroll(_stars_far, scroll_speed * 0.25 * delta, vp)
	_scroll(_stars_mid, scroll_speed * 0.6 * delta, vp)
	_scroll(_stars_near, scroll_speed * 1.2 * delta, vp)
	for i in _clouds.size():
		var c := _clouds[i]
		c.y += scroll_speed * 0.12 * delta
		if c.y - c.z > vp.y + 40.0:
			c.y = -c.z - 40.0
			c.x = _rng.randf() * vp.x
		_clouds[i] = c
	var pos: Vector2 = _planet["pos"]
	pos.y += scroll_speed * 0.08 * delta
	var r: float = _planet["r"]
	if pos.y - r > vp.y + 60.0:
		pos.y = -r - _rng.randf_range(200.0, 600.0)
		pos.x = _rng.randf_range(80.0, vp.x - 80.0)
		_planet["shade"] = _rng.randf()
	_planet["pos"] = pos
	queue_redraw()


func _scroll(stars: Array[Vector2], amount: float, vp: Vector2) -> void:
	for i in stars.size():
		stars[i].y += amount
		if stars[i].y > vp.y:
			stars[i].y = -2.0
			stars[i].x = _rng.randf() * vp.x


func _draw() -> void:
	var vp := get_viewport_rect().size
	# Vertical gradient: deep space up top fading toward the mission tint.
	var top := Color(0.03, 0.04, 0.10)
	var bottom := Color(
		0.03 + tint.r * 0.10, 0.04 + tint.g * 0.10, 0.10 + tint.b * 0.12)
	var bands := 8
	for i in bands:
		var c := top.lerp(bottom, float(i) / float(bands - 1))
		draw_rect(Rect2(0.0, vp.y * i / bands, vp.x, vp.y / bands + 1.0), c)
	# Nebula clouds — faked soft blobs: concentric rings, denser core.
	for c in _clouds:
		for ring in 3:
			var rr := c.z * (1.0 - ring * 0.28)
			var a := 0.05 + 0.04 * ring
			draw_circle(Vector2(c.x, c.y), rr, Color(tint.r, tint.g, tint.b, a))
	# Planet with a crescent shadow and a faint lit rim.
	var ppos: Vector2 = _planet["pos"]
	var pr: float = _planet["r"]
	var shade: float = _planet["shade"]
	var body := Color(
		tint.r * (0.4 + shade * 0.5) + 0.06,
		tint.g * 0.6 + 0.08,
		tint.b * 0.9 + 0.10, 0.9)
	draw_circle(ppos, pr, body)
	draw_circle(ppos + Vector2(pr * 0.22, pr * 0.26), pr * 0.88, Color(0.02, 0.02, 0.06, 0.45))
	draw_arc(ppos, pr, PI * 1.05, PI * 1.85, 24, Color(1.0, 1.0, 1.0, 0.18), 2.0)
	# Stars — three depths, near layer twinkles.
	for s in _stars_far:
		draw_circle(s, 1.0, Color(0.7, 0.8, 1.0, 0.40))
	for s in _stars_mid:
		draw_circle(s, 1.3, Color(0.8, 0.88, 1.0, 0.60))
	for i in _stars_near.size():
		var tw := 0.55 + 0.4 * sin(_t * 2.4 + float(i) * 1.7)
		draw_circle(_stars_near[i], 1.8, Color(0.95, 0.97, 1.0, tw))
