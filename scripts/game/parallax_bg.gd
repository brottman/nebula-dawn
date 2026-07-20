extends Node2D
## Parallax starfield + nebula color wash.

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _stars_far: Array[Vector2] = []
var _stars_near: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var vp := get_viewport_rect().size
	for i in 60:
		_stars_far.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))
	for i in 35:
		_stars_near.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))


func set_tint(c: Color) -> void:
	tint = c
	queue_redraw()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	_scroll(_stars_far, scroll_speed * 0.35 * delta, vp)
	_scroll(_stars_near, scroll_speed * 1.1 * delta, vp)
	queue_redraw()


func _scroll(stars: Array[Vector2], amount: float, vp: Vector2) -> void:
	for i in stars.size():
		stars[i].y += amount
		if stars[i].y > vp.y:
			stars[i].y = -2.0
			stars[i].x = _rng.randf() * vp.x


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.05, 0.12))
	# Nebula wash
	draw_circle(Vector2(vp.x * 0.3, vp.y * 0.25), 180.0, Color(tint.r, tint.g, tint.b, 0.22))
	draw_circle(Vector2(vp.x * 0.75, vp.y * 0.55), 220.0, Color(tint.r * 1.2, tint.g * 0.6, tint.b * 0.9, 0.18))
	for s in _stars_far:
		draw_circle(s, 1.0, Color(0.7, 0.8, 1.0, 0.45))
	for s in _stars_near:
		draw_circle(s, 1.6, Color(0.9, 0.95, 1.0, 0.85))
