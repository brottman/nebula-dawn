extends Node2D
## Vertical-shooter world layers (speeds relative to playfield scroll):
##   Far Background  0.1x — nebula, distant stars, planet horizons
##   Midground       0.5x — stations, terrain bands, capital ships
##   Playfield Grid  1.0x — subtle grid where combat lives
##   Foreground      1.5x — debris / lower clouds (depth + sight blockage)

const SPEED_FAR := 0.1
const SPEED_MID := 0.5
const SPEED_GRID := 1.0
const SPEED_FG := 1.5

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _far: _FarLayer
var _mid: _MidLayer
var _grid: _GridLayer
var _fg: _ForegroundLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_far = _FarLayer.new()
	_far.name = "FarBackground"
	_far.z_index = -30
	add_child(_far)

	_mid = _MidLayer.new()
	_mid.name = "Midground"
	_mid.z_index = -20
	add_child(_mid)

	_grid = _GridLayer.new()
	_grid.name = "PlayfieldGrid"
	_grid.z_index = -10
	add_child(_grid)

	_fg = _ForegroundLayer.new()
	_fg.name = "ForegroundHazards"
	# Absolute Z so this draws above Entities / Player / Projectiles.
	_fg.z_as_relative = false
	_fg.z_index = 50
	add_child(_fg)

	var vp := get_viewport_rect().size
	_far.setup(vp, tint, _rng)
	_mid.setup(vp, tint, _rng)
	_grid.setup(vp, tint, _rng)
	_fg.setup(vp, tint, _rng)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	var vp := get_viewport_rect().size
	_far.on_resize(vp)
	_mid.on_resize(vp)
	_grid.on_resize(vp)
	_fg.on_resize(vp)


func set_tint(c: Color) -> void:
	tint = c
	if _far:
		_far.tint = c
		_far.queue_redraw()
	if _mid:
		_mid.tint = c
		_mid.queue_redraw()
	if _grid:
		_grid.tint = c
		_grid.queue_redraw()
	if _fg:
		_fg.tint = c
		_fg.queue_redraw()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	_far.tick(delta, scroll_speed * SPEED_FAR, vp)
	_mid.tick(delta, scroll_speed * SPEED_MID, vp)
	_grid.tick(delta, scroll_speed * SPEED_GRID, vp)
	_fg.tick(delta, scroll_speed * SPEED_FG, vp)


# ---------------------------------------------------------------------------
# Far Background — 0.1x
# ---------------------------------------------------------------------------
class _FarLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var stars: Array[Vector2] = []
	var clouds: Array[Vector3] = [] # x, y, radius
	var planet := {"pos": Vector2(340, 200), "r": 70.0, "shade": 0.5}
	var horizon_y: float = 0.0
	var _t: float = 0.0
	var _rng: RandomNumberGenerator

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		stars.clear()
		clouds.clear()
		for i in 90:
			stars.append(Vector2(rng.randf() * vp.x, rng.randf() * vp.y))
		for i in 6:
			clouds.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(100.0, 220.0)))
		planet["pos"] = Vector2(rng.randf_range(80.0, vp.x - 80.0), vp.y * 0.28)
		planet["shade"] = rng.randf()
		horizon_y = vp.y * 0.78

	func on_resize(vp: Vector2) -> void:
		horizon_y = vp.y * 0.78
		queue_redraw()

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_t += delta
		for i in stars.size():
			stars[i].y += speed * delta
			if stars[i].y > vp.y:
				stars[i].y = -2.0
				stars[i].x = _rng.randf() * vp.x
		for i in clouds.size():
			var c := clouds[i]
			c.y += speed * delta
			if c.y - c.z > vp.y + 40.0:
				c.y = -c.z - 40.0
				c.x = _rng.randf() * vp.x
			clouds[i] = c
		var pos: Vector2 = planet["pos"]
		pos.y += speed * delta
		var r: float = planet["r"]
		if pos.y - r > vp.y + 80.0:
			pos.y = -r - _rng.randf_range(280.0, 700.0)
			pos.x = _rng.randf_range(70.0, vp.x - 70.0)
			planet["shade"] = _rng.randf()
		planet["pos"] = pos
		horizon_y += speed * delta * 0.35
		if horizon_y > vp.y + 40.0:
			horizon_y = -40.0
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var top := Color(0.02, 0.03, 0.08)
		var bottom := Color(0.03 + tint.r * 0.12, 0.04 + tint.g * 0.10, 0.10 + tint.b * 0.14)
		for i in 10:
			var c := top.lerp(bottom, float(i) / 9.0)
			draw_rect(Rect2(0.0, vp.y * i / 10.0, vp.x, vp.y / 10.0 + 1.0), c)
		# Soft nebula wash
		for c in clouds:
			for ring in 3:
				var rr := c.z * (1.0 - ring * 0.28)
				draw_circle(Vector2(c.x, c.y), rr, Color(tint.r, tint.g, tint.b, 0.04 + 0.035 * ring))
		# Distant planet horizon arc
		var hx := vp.x * 0.5
		var hr := vp.x * 0.85
		draw_circle(Vector2(hx, horizon_y + hr * 0.72), hr, Color(tint.r * 0.35, tint.g * 0.4, tint.b * 0.55, 0.22))
		draw_circle(Vector2(hx, horizon_y + hr * 0.72), hr * 0.92, Color(0.02, 0.03, 0.06, 0.35))
		# Planet body
		var ppos: Vector2 = planet["pos"]
		var pr: float = planet["r"]
		var shade: float = planet["shade"]
		var body := Color(
			tint.r * (0.4 + shade * 0.5) + 0.05,
			tint.g * 0.55 + 0.07,
			tint.b * 0.85 + 0.09, 0.88)
		draw_circle(ppos, pr, body)
		draw_circle(ppos + Vector2(pr * 0.22, pr * 0.26), pr * 0.88, Color(0.02, 0.02, 0.06, 0.42))
		draw_arc(ppos, pr, PI * 1.05, PI * 1.85, 24, Color(1.0, 1.0, 1.0, 0.16), 2.0)
		for s in stars:
			draw_circle(s, 1.0, Color(0.7, 0.8, 1.0, 0.38))


# ---------------------------------------------------------------------------
# Midground — 0.5x
# ---------------------------------------------------------------------------
class _MidLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	## kind 0 = station, 1 = capital ship, 2 = terrain slab
	var props: Array[Dictionary] = []
	var _rng: RandomNumberGenerator

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		props.clear()
		for i in 7:
			_spawn_prop(vp, rng.randf() * vp.y)

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func _spawn_prop(vp: Vector2, y: float) -> void:
		var kind := _rng.randi() % 3
		var w := _rng.randf_range(70.0, 160.0)
		var h := _rng.randf_range(28.0, 70.0)
		if kind == 1:
			w = _rng.randf_range(120.0, 220.0)
			h = _rng.randf_range(22.0, 40.0)
		props.append({
			"kind": kind,
			"pos": Vector2(_rng.randf_range(20.0, vp.x - 20.0), y),
			"size": Vector2(w, h),
			"phase": _rng.randf() * TAU,
		})

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		for i in props.size():
			var p: Dictionary = props[i]
			var pos: Vector2 = p["pos"]
			pos.y += speed * delta
			var h: float = p["size"].y
			if pos.y - h > vp.y + 60.0:
				pos.y = -h - _rng.randf_range(80.0, 320.0)
				pos.x = _rng.randf_range(20.0, vp.x - 20.0)
				p["kind"] = _rng.randi() % 3
				p["phase"] = _rng.randf() * TAU
			p["pos"] = pos
			props[i] = p
		queue_redraw()

	func _draw() -> void:
		var base := Color(tint.r * 0.55 + 0.05, tint.g * 0.55 + 0.06, tint.b * 0.7 + 0.08, 0.55)
		var edge := Color(tint.r * 0.8 + 0.1, tint.g * 0.7 + 0.1, tint.b * 0.9 + 0.12, 0.35)
		for p in props:
			var pos: Vector2 = p["pos"]
			var sz: Vector2 = p["size"]
			var kind: int = p["kind"]
			match kind:
				0: # Space station — blocky modules
					var origin := pos - sz * 0.5
					draw_rect(Rect2(origin, sz), base)
					draw_rect(Rect2(origin + Vector2(sz.x * 0.15, -sz.y * 0.35), Vector2(sz.x * 0.7, sz.y * 0.35)), base.darkened(0.15))
					draw_rect(Rect2(origin + Vector2(sz.x * 0.35, sz.y * 0.2), Vector2(sz.x * 0.3, sz.y * 0.55)), edge)
					# Window lights
					for n in 4:
						var wx := origin.x + sz.x * (0.18 + n * 0.18)
						draw_rect(Rect2(wx, origin.y + sz.y * 0.35, 4.0, 4.0), Color(1.0, 0.9, 0.5, 0.45))
				1: # Capital ship silhouette — long hull + fins
					var hull := PackedVector2Array([
						pos + Vector2(-sz.x * 0.5, 0),
						pos + Vector2(-sz.x * 0.15, -sz.y * 0.55),
						pos + Vector2(sz.x * 0.5, 0),
						pos + Vector2(-sz.x * 0.15, sz.y * 0.45),
					])
					draw_colored_polygon(hull, base.darkened(0.1))
					draw_line(pos + Vector2(-sz.x * 0.2, 0), pos + Vector2(sz.x * 0.35, 0), edge, 2.0)
					draw_circle(pos + Vector2(sz.x * 0.28, 0), 3.0, Color(1.0, 0.6, 0.3, 0.5))
				_: # Terrain / planetary crust slab
					var origin := pos - Vector2(sz.x * 0.5, 0)
					var pts := PackedVector2Array([
						origin,
						origin + Vector2(sz.x * 0.25, -sz.y * 0.4),
						origin + Vector2(sz.x * 0.55, -sz.y * 0.15),
						origin + Vector2(sz.x, sz.y * 0.1),
						origin + Vector2(sz.x, sz.y * 0.55),
						origin + Vector2(0, sz.y * 0.5),
					])
					draw_colored_polygon(pts, Color(base.r, base.g, base.b, 0.4))


# ---------------------------------------------------------------------------
# Playfield Grid — 1.0x
# ---------------------------------------------------------------------------
class _GridLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var offset_y: float = 0.0
	const CELL := 48.0

	func setup(_vp: Vector2, t: Color, _rng: RandomNumberGenerator) -> void:
		tint = t
		offset_y = 0.0

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func tick(delta: float, speed: float, _vp: Vector2) -> void:
		offset_y = fmod(offset_y + speed * delta, CELL)
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var line := Color(tint.r * 0.5 + 0.15, tint.g * 0.55 + 0.2, tint.b * 0.8 + 0.25, 0.07)
		var accent := Color(line.r, line.g, line.b, 0.12)
		var y := -CELL + offset_y
		var row := 0
		while y < vp.y + CELL:
			draw_line(Vector2(0, y), Vector2(vp.x, y), line if row % 2 == 0 else accent, 1.0)
			y += CELL
			row += 1
		var x := 0.0
		var col := 0
		while x < vp.x + CELL:
			draw_line(Vector2(x, 0), Vector2(x, vp.y), line if col % 3 != 0 else accent, 1.0)
			x += CELL
			col += 1


# ---------------------------------------------------------------------------
# Foreground Hazards — 1.5x
# ---------------------------------------------------------------------------
class _ForegroundLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var debris: Array[Dictionary] = []
	var wisps: Array[Vector3] = [] # x, y, width
	var _rng: RandomNumberGenerator

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		debris.clear()
		wisps.clear()
		for i in 10:
			_spawn_debris(vp, rng.randf() * vp.y)
		for i in 4:
			wisps.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(60.0, 140.0)))

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func _spawn_debris(vp: Vector2, y: float) -> void:
		debris.append({
			"pos": Vector2(_rng.randf() * vp.x, y),
			"size": _rng.randf_range(4.0, 14.0),
			"rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-2.5, 2.5),
			"pts": _make_rock(_rng.randf_range(4.0, 14.0)),
		})

	func _make_rock(r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 5 + _rng.randi() % 3
		for i in n:
			var a := TAU * float(i) / float(n)
			var rr := r * _rng.randf_range(0.55, 1.1)
			pts.append(Vector2(cos(a), sin(a)) * rr)
		return pts

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		for i in debris.size():
			var d: Dictionary = debris[i]
			var pos: Vector2 = d["pos"]
			pos.y += speed * delta
			d["rot"] = float(d["rot"]) + float(d["spin"]) * delta
			if pos.y > vp.y + 30.0:
				pos.y = -20.0 - _rng.randf_range(0.0, 120.0)
				pos.x = _rng.randf() * vp.x
				d["pts"] = _make_rock(_rng.randf_range(4.0, 14.0))
				d["size"] = _rng.randf_range(4.0, 14.0)
			d["pos"] = pos
			debris[i] = d
		for i in wisps.size():
			var w := wisps[i]
			w.y += speed * delta * 0.85
			if w.y > vp.y + 50.0:
				w.y = -50.0
				w.x = _rng.randf() * vp.x
				w.z = _rng.randf_range(60.0, 140.0)
			wisps[i] = w
		queue_redraw()

	func _draw() -> void:
		# Lower cloud wisps — soft sight blockage
		for w in wisps:
			var a := 0.10
			draw_circle(Vector2(w.x, w.y), w.z * 0.55, Color(tint.r * 0.6 + 0.2, tint.g * 0.6 + 0.22, tint.b * 0.7 + 0.25, a))
			draw_circle(Vector2(w.x + w.z * 0.25, w.y + 8.0), w.z * 0.4, Color(0.08, 0.09, 0.14, a * 0.8))
		# Space debris chunks
		for d in debris:
			var pos: Vector2 = d["pos"]
			var rot: float = d["rot"]
			var pts: PackedVector2Array = d["pts"]
			var xform := Transform2D(rot, pos)
			var world := PackedVector2Array()
			for p in pts:
				world.append(xform * p)
			draw_colored_polygon(world, Color(0.55, 0.52, 0.5, 0.55))
			if world.size() >= 2:
				draw_polyline(world + PackedVector2Array([world[0]]), Color(0.85, 0.8, 0.75, 0.35), 1.0)
