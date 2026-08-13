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
## Ground terrain drifts a touch faster than midground so it reads as near.
const SPEED_GROUND := 0.72

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _far: _FarLayer
var _mid: _MidLayer
var _grid: _GridLayer
var _fg: _ForegroundLayer
var _terrain: _TerrainLayer
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

	_terrain = _TerrainLayer.new()
	_terrain.name = "GroundBase"
	_terrain.z_index = -15
	add_child(_terrain)

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
	_terrain.setup(vp, tint, _rng)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	var vp := get_viewport_rect().size
	_far.on_resize(vp)
	_mid.on_resize(vp)
	_grid.on_resize(vp)
	_fg.on_resize(vp)
	_terrain.on_resize(vp)


func set_terrain(style: StringName) -> void:
	if _terrain:
		_terrain.set_style(style)


func set_terrain_random() -> void:
	if _terrain:
		_terrain.set_random_style()


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
	if _terrain:
		_terrain.tint = c
		_terrain.queue_redraw()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	_far.tick(delta, scroll_speed * SPEED_FAR, vp)
	_mid.tick(delta, scroll_speed * SPEED_MID, vp)
	_grid.tick(delta, scroll_speed * SPEED_GRID, vp)
	_fg.tick(delta, scroll_speed * SPEED_FG, vp)
	_terrain.tick(delta, scroll_speed * SPEED_GROUND, vp)


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


# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Ground Base — military / space base terrain you fly over (0.72x)
# ---------------------------------------------------------------------------
class _TerrainLayer extends Node2D:
	## A fixed ground band with a scrolling strip of base structures. Far
	## structures sit at the horizon (atmospheric haze), near ones read dark at
	## the bottom. The band itself carries scrolling base detail (runways,
	## taxiways, perimeter lights) so the ground reads as a built-up base.

	const GROUND_RATIO := 0.66 ## Top edge of the ground band.
	const STRUCT_COUNT := 9
	const WIDE_KINDS := [&"barracks", &"hangar", &"deck", &"gate", &"silo", &"block"]
	const TALL_KINDS := [&"watchtower", &"radar_dish", &"antenna", &"spire", &"pylon", &"floodlight"]

	var style: StringName = &""
	var tint: Color = Color(0.12, 0.16, 0.38)
	var structures: Array[Dictionary] = []
	var _rng: RandomNumberGenerator
	var _time: float = 0.0
	var _scroll_accum: float = 0.0

	## style -> kinds + palette (haze = far band, deep = near band, edge = glow).
	## detail: runway | road | glow | none  (scrolling base-floor markings).
	const STYLES := {
		&"city": {
			"kinds": [&"barracks", &"hangar", &"watchtower", &"radar_dish", &"block", &"gate"],
			"haze": Color(0.30, 0.26, 0.20),
			"deep": Color(0.05, 0.04, 0.03),
			"edge": Color(1.0, 0.62, 0.28),
			"detail": &"runway",
		},
		&"mines": {
			"kinds": [&"silo", &"silo", &"watchtower", &"barracks", &"crater", &"gate"],
			"haze": Color(0.26, 0.22, 0.18),
			"deep": Color(0.04, 0.035, 0.03),
			"edge": Color(1.0, 0.75, 0.35),
			"detail": &"road",
		},
		&"biolum": {
			"kinds": [&"hangar", &"pod", &"pod", &"dome", &"silo", &"gate"],
			"haze": Color(0.16, 0.22, 0.20),
			"deep": Color(0.02, 0.05, 0.04),
			"edge": Color(0.55, 1.0, 0.75),
			"detail": &"glow",
		},
		&"factory": {
			"kinds": [&"hangar", &"crane", &"block", &"silo", &"watchtower", &"floodlight"],
			"haze": Color(0.22, 0.24, 0.26),
			"deep": Color(0.035, 0.045, 0.05),
			"edge": Color(0.45, 0.9, 1.0),
			"detail": &"road",
		},
		&"fleet": {
			"kinds": [&"deck", &"control_tower", &"hangar", &"aa_turret", &"radar_dish", &"gate"],
			"haze": Color(0.18, 0.22, 0.30),
			"deep": Color(0.03, 0.04, 0.07),
			"edge": Color(0.4, 0.7, 1.0),
			"detail": &"runway",
		},
		&"mirror": {
			"kinds": [&"crystal", &"crystal", &"gate", &"watchtower", &"dome", &"floodlight"],
			"haze": Color(0.16, 0.24, 0.30),
			"deep": Color(0.02, 0.045, 0.06),
			"edge": Color(0.55, 0.9, 1.0),
			"detail": &"glow",
		},
		&"storm": {
			"kinds": [&"pylon", &"pylon", &"silo", &"watchtower", &"barracks", &"aa_turret"],
			"haze": Color(0.14, 0.20, 0.28),
			"deep": Color(0.02, 0.035, 0.06),
			"edge": Color(0.55, 0.8, 1.0),
			"detail": &"road",
		},
		&"wake": {
			"kinds": [&"ruin", &"ruin", &"gate", &"barracks", &"radar_dish", &"water_tower"],
			"haze": Color(0.18, 0.16, 0.26),
			"deep": Color(0.03, 0.025, 0.05),
			"edge": Color(0.7, 0.55, 1.0),
			"detail": &"none",
		},
		&"scrap": {
			"kinds": [&"junk", &"junk", &"hangar", &"crane", &"aa_turret", &"barracks"],
			"haze": Color(0.26, 0.20, 0.14),
			"deep": Color(0.05, 0.035, 0.02),
			"edge": Color(1.0, 0.6, 0.3),
			"detail": &"road",
		},
		&"flare": {
			"kinds": [&"spire", &"spire", &"gate", &"control_tower", &"aa_turret", &"floodlight"],
			"haze": Color(0.28, 0.20, 0.12),
			"deep": Color(0.055, 0.03, 0.015),
			"edge": Color(1.0, 0.85, 0.4),
			"detail": &"runway",
		},
	}
	const STYLE_KEYS: Array[StringName] = [
		&"city", &"mines", &"biolum", &"factory", &"fleet",
		&"mirror", &"storm", &"wake", &"scrap", &"flare",
	]

	func setup(_vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_random_style() -> void:
		set_style(STYLE_KEYS[_rng.randi() % STYLE_KEYS.size()])

	func set_style(s: StringName) -> void:
		style = s
		structures.clear()
		_scroll_accum = 0.0
		var vp := get_viewport_rect().size
		if style == &"":
			queue_redraw()
			return
		for i in STRUCT_COUNT:
			structures.append(_new_structure(vp, true))
		queue_redraw()

	func _new_structure(vp: Vector2, prefill: bool = false) -> Dictionary:
		var kinds: Array = STYLES.get(style, {}).get("kinds", [&"block"])
		var kind: StringName = kinds[_rng.randi() % kinds.size()]
		var wide := kind in WIDE_KINDS
		var tall := kind in TALL_KINDS
		var w := _rng.randf_range(30.0, 64.0)
		var h := _rng.randf_range(34.0, 88.0)
		if wide:
			w = _rng.randf_range(52.0, 88.0)
			h = _rng.randf_range(26.0, 48.0)
		if tall:
			w = _rng.randf_range(18.0, 30.0)
			h = _rng.randf_range(56.0, 110.0)
		var ground_y := vp.y * GROUND_RATIO
		return {
			"kind": kind,
			"x": _rng.randf_range(28.0, vp.x - 28.0),
			"w": w,
			"h": h,
			"y": -h - _rng.randf_range(0.0, 120.0) if prefill else -h - 30.0,
			"seed": _rng.randi(),
			"grow": _rng.randf_range(0.8, 1.3),
		}

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_time += delta
		_scroll_accum += speed * delta
		if style == &"":
			return
		var ground_y := vp.y * GROUND_RATIO
		for i in structures.size():
			var s: Dictionary = structures[i]
			s["y"] = float(s["y"]) + speed * delta
			if float(s["y"]) > vp.y - ground_y + float(s["h"]) + 40.0:
				structures[i] = _new_structure(vp)
			else:
				structures[i] = s
		queue_redraw()

	func _palette() -> Dictionary:
		return STYLES.get(style, STYLES[&"city"])

	func _structure_color(y: float, vp_h: float, ground_y: float) -> Color:
		## Far structures near the horizon sit in haze; near ones go dark.
		var t := clampf((y - ground_y) / maxf(1.0, vp_h - ground_y), 0.0, 1.0)
		var pal: Dictionary = _palette()
		return pal["haze"].lerp(pal["deep"], t)

	func _draw() -> void:
		var vp := get_viewport_rect().size
		if style == &"" or vp.y <= 0.0:
			return
		var pal: Dictionary = _palette()
		var ground_y := vp.y * GROUND_RATIO
		var band_h := vp.y - ground_y
		var edge: Color = pal["edge"]
		# Band: haze at the horizon, deep at the camera.
		var bands := 12
		for i in bands:
			var t := float(i) / float(bands - 1)
			var c: Color = pal["haze"].lerp(pal["deep"], t)
			draw_rect(Rect2(0.0, ground_y + i * band_h / bands, vp.x, band_h / bands + 1.0), c)
		# Horizon glow + faint accent wash.
		draw_rect(Rect2(0.0, ground_y - 2.0, vp.x, 3.0), Color(edge.r, edge.g, edge.b, 0.5))
		draw_rect(Rect2(0.0, ground_y, vp.x, band_h * 0.45), Color(edge.r, edge.g, edge.b, 0.05))
		_draw_ground_detail(vp, ground_y, band_h, pal, edge)
		for s in structures:
			_draw_structure(s, vp, ground_y, edge)

	func _draw_ground_detail(vp: Vector2, ground_y: float, band_h: float, pal: Dictionary, edge: Color) -> void:
		## Scrolling base-floor markings so the ground reads as an installation.
		var detail: StringName = pal.get("detail", &"none")
		var light := Color(edge.r, edge.g, edge.b, 0.35)
		var faint := Color(edge.r, edge.g, edge.b, 0.14)
		var dash := 60.0
		var off := fmod(_scroll_accum, dash)
		match detail:
			&"runway":
				# Centerline dashes + edge lights, like a flight deck / airbase strip.
				var cx := vp.x * 0.5
				for y in range(-60, int(band_h) + 60, int(dash)):
					var dy := ground_y + float(y) + off
					draw_rect(Rect2(cx - 2.5, dy, 5.0, 26.0), light)
					draw_circle(Vector2(cx - 38.0, dy + 13.0), 1.5, faint)
					draw_circle(Vector2(cx + 38.0, dy + 13.0), 1.5, faint)
			&"road":
				# Twin taxiway bands with dashed center lines.
				for rx in [vp.x * 0.18, vp.x * 0.82]:
					draw_rect(Rect2(rx - 6.0, ground_y, 12.0, band_h), Color(pal["haze"].r, pal["haze"].g, pal["haze"].b, 0.45))
					for y in range(-60, int(band_h) + 60, int(dash)):
						var dy := ground_y + float(y) + off
						draw_rect(Rect2(rx - 1.5, dy, 3.0, 20.0), light)
			&"glow":
				# Scattered bio / crystal luminescence on the floor.
				for i in 8:
					var gx := fmod(float(_hash01(int(_scroll_accum * 0.5), i)) * vp.x + off * 0.4, vp.x)
					var gy := ground_y + fmod(float(_hash01(7, i * 3)) * band_h + off, band_h)
					draw_circle(Vector2(gx, gy), 1.8, faint)
					draw_circle(Vector2(gx, gy), 4.0, Color(edge.r, edge.g, edge.b, 0.06))
			_:
				pass

	func _hash01(seed: int, i: int) -> float:
		var v := sin(float(seed * 97 + i * 131)) * 43758.5453
		return v - floor(v)

	func _light(seed: int, i: int, x: float, y: float, w: float, h: float) -> void:
		var lit := _hash01(seed, i)
		if lit < 0.35:
			return
		var col := Color(1.0, 0.85, 0.55, 0.85) if lit < 0.8 else Color(0.6, 0.9, 1.0, 0.7)
		draw_rect(Rect2(x, y, w, h), col)

	func _beacon(seed: int, x: float, y: float) -> void:
		var blink := 0.5 + 0.5 * sin(_time * 4.0 + float(seed))
		var a := 0.8 if GameState.reduce_flashes else 0.4 + 0.6 * blink
		draw_circle(Vector2(x, y), 2.2, Color(1.0, 0.3, 0.25, a))

	func _draw_structure(s: Dictionary, vp: Vector2, ground_y: float, edge: Color) -> void:
		var kind: StringName = s["kind"]
		var x: float = s["x"]
		var w: float = s["w"] * float(s["grow"])
		var h: float = s["h"] * float(s["grow"])
		var y: float = ground_y + float(s["y"]) ## top of the structure
		var bottom := ground_y + float(s["y"]) + h
		if bottom < 0.0 or y > vp.y:
			return
		var col := _structure_color(y, vp.y, ground_y)
		var seed: int = s["seed"]
		var accent := Color(edge.r, edge.g, edge.b, 0.9)
		var dark := col.darkened(0.45)
		var x0 := x - w * 0.5
		match kind:
			&"barracks":
				# Long low building with a pitched roof and window row.
				draw_rect(Rect2(x0, y + h * 0.18, w, h * 0.82), col)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, y + h * 0.18), Vector2(x + w * 0.5, y), Vector2(x0 + w, y + h * 0.18),
				]), dark)
				draw_line(Vector2(x - w * 0.4, y + h * 0.16), Vector2(x + w * 0.4, y + h * 0.16), accent, 1.2)
				draw_rect(Rect2(x - w * 0.08, bottom - h * 0.42, w * 0.16, h * 0.42), dark)
				for i in 6:
					_light(seed, i, x0 + w * (0.1 + i * 0.13), y + h * 0.32, w * 0.07, h * 0.12)
			&"hangar":
				# Half-cylinder hangar with a big dark door.
				var pts := PackedVector2Array()
				var seg := 10
				for i in seg + 1:
					var a := PI - PI * float(i) / float(seg)
					pts.append(Vector2(x + cos(a) * w * 0.5, bottom - h + sin(a) * h))
				pts.append(Vector2(x0 + w, bottom))
				pts.append(Vector2(x0, bottom))
				draw_colored_polygon(pts, col)
				for i in 3:
					var ry := bottom - h * (0.35 + i * 0.25)
					draw_line(Vector2(x0 + w * 0.25, ry), Vector2(x0 + w * 0.75, ry), dark, 1.4)
				draw_rect(Rect2(x - w * 0.16, bottom - h * 0.52, w * 0.32, h * 0.52), dark)
				draw_rect(Rect2(x - w * 0.16, bottom - h * 0.52, w * 0.32, h * 0.1), Color(edge.r, edge.g, edge.b, 0.3))
				draw_circle(Vector2(x - w * 0.16, bottom - h * 0.52), 1.6, accent)
				draw_circle(Vector2(x + w * 0.16, bottom - h * 0.52), 1.6, accent)
			&"radar_dish":
				# Pedestal + tilted dish — instant "airbase" read.
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.3, bottom), Vector2(x + w * 0.3, bottom),
					Vector2(x + w * 0.12, y + h * 0.55), Vector2(x - w * 0.12, y + h * 0.55),
				]), dark)
				draw_line(Vector2(x, bottom - h * 0.1), Vector2(x, y + h * 0.45), col, 3.0)
				var dc := Vector2(x, y + h * 0.42)
				var dr := h * 0.34
				var dp := PackedVector2Array()
				for i in 16:
					var a := -PI * 0.28 + PI * 0.28 * float(i) / 15.0
					var p := Vector2(cos(a) * dr, sin(a) * dr * 0.45)
					dp.append(dc + p.rotated(-0.5))
				draw_colored_polygon(dp, dark.lightened(0.1))
				draw_polyline(dp + PackedVector2Array([dp[0]]), accent, 1.6)
				draw_circle(dc + Vector2(-dr * 0.5, 0).rotated(-0.5), 2.2, accent)
				_beacon(seed, x, y + h * 0.12)
			&"silo":
				# Missile silo bunker with a raised warhead.
				draw_rect(Rect2(x0, y + h * 0.34, w, h * 0.66), col)
				draw_rect(Rect2(x0, y + h * 0.34, w, h * 0.14), dark)
				draw_circle(Vector2(x, y + h * 0.48), w * 0.17, dark.darkened(0.2))
				draw_arc(Vector2(x, y + h * 0.48), w * 0.17, 0.0, TAU, 12, accent, 1.4)
				draw_line(Vector2(x, y + h * 0.48), Vector2(x - w * 0.16, y + h * 0.12), col, 2.4)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.16, y + h * 0.18), Vector2(x - w * 0.16, y + h * 0.08),
					Vector2(x - w * 0.1, y + h * 0.12),
				]), dark)
				_beacon(seed, x - w * 0.16, y + h * 0.05)
			&"watchtower":
				# Four-leg tower with a guard cabin + floodlight.
				draw_line(Vector2(x - w * 0.28, bottom), Vector2(x - w * 0.1, y + h * 0.26), dark, 2.2)
				draw_line(Vector2(x + w * 0.28, bottom), Vector2(x + w * 0.1, y + h * 0.26), dark, 2.2)
				draw_line(Vector2(x - w * 0.16, bottom), Vector2(x - w * 0.04, y + h * 0.26), dark, 1.4)
				draw_line(Vector2(x + w * 0.16, bottom), Vector2(x + w * 0.04, y + h * 0.26), dark, 1.4)
				draw_rect(Rect2(x - w * 0.24, y, w * 0.48, h * 0.28), col)
				draw_rect(Rect2(x - w * 0.24, y + h * 0.28, w * 0.48, h * 0.05), dark)
				_light(seed, 1, x - w * 0.14, y + h * 0.06, w * 0.28, h * 0.14)
				draw_line(Vector2(x - w * 0.28, y), Vector2(x + w * 0.28, y), dark, 1.6)
				draw_circle(Vector2(x, y + h * 0.26), 2.0, accent)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.1, y + h * 0.3), Vector2(x + w * 0.1, y + h * 0.3),
					Vector2(x + w * 0.18, y + h * 0.62), Vector2(x - w * 0.18, y + h * 0.62),
				]), Color(edge.r, edge.g, edge.b, 0.07))
			&"control_tower":
				# Round control tower with a glowing glass band.
				draw_rect(Rect2(x - w * 0.14, y + h * 0.28, w * 0.28, h * 0.72), col)
				draw_rect(Rect2(x - w * 0.3, y, w * 0.6, h * 0.3), col)
				draw_rect(Rect2(x - w * 0.26, y + h * 0.08, w * 0.52, h * 0.1), Color(edge.r, edge.g, edge.b, 0.55))
				draw_line(Vector2(x - w * 0.3, y), Vector2(x + w * 0.3, y), dark, 1.6)
				draw_line(Vector2(x, y), Vector2(x, y - h * 0.08), col, 1.6)
				draw_circle(Vector2(x, y - h * 0.08), 1.8, accent)
				_beacon(seed, x - w * 0.3, y + h * 0.05)
			&"aa_turret":
				# Twin-barrel anti-air emplacement.
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.4, bottom), Vector2(x + w * 0.4, bottom),
					Vector2(x + w * 0.2, y + h * 0.62), Vector2(x - w * 0.2, y + h * 0.62),
				]), dark)
				draw_rect(Rect2(x - w * 0.14, y + h * 0.5, w * 0.28, h * 0.14), col)
				draw_line(Vector2(x - w * 0.08, y + h * 0.5), Vector2(x - w * 0.22, y + h * 0.1), col, 2.2)
				draw_line(Vector2(x + w * 0.08, y + h * 0.5), Vector2(x + w * 0.22, y + h * 0.1), col, 2.2)
				draw_circle(Vector2(x - w * 0.22, y + h * 0.1), 1.6, accent)
				draw_circle(Vector2(x + w * 0.22, y + h * 0.1), 1.6, accent)
				_beacon(seed, x, y + h * 0.5)
			&"water_tower":
				# Four-leg tank with a conical roof.
				draw_line(Vector2(x - w * 0.22, bottom), Vector2(x - w * 0.12, y + h * 0.42), dark, 2.2)
				draw_line(Vector2(x + w * 0.22, bottom), Vector2(x + w * 0.12, y + h * 0.42), dark, 2.2)
				draw_line(Vector2(x - w * 0.08, bottom), Vector2(x - w * 0.04, y + h * 0.42), dark, 1.4)
				draw_line(Vector2(x + w * 0.08, bottom), Vector2(x + w * 0.04, y + h * 0.42), dark, 1.4)
				draw_rect(Rect2(x - w * 0.28, y + h * 0.18, w * 0.56, h * 0.28), col)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.28, y + h * 0.18), Vector2(x + w * 0.28, y + h * 0.18),
					Vector2(x, y),
				]), dark)
				draw_line(Vector2(x, y + h * 0.18), Vector2(x, y + h * 0.46), dark, 1.6)
				draw_circle(Vector2(x, y), 1.6, accent)
			&"floodlight":
				# Pole light with a faint beam cone.
				draw_line(Vector2(x, bottom), Vector2(x, y), col, 2.0)
				draw_rect(Rect2(x - 2.5, y - 3.0, 5.0, 5.0), dark)
				draw_circle(Vector2(x, y - 3.0), 2.0, Color(1.0, 0.9, 0.6, 0.9))
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 3.0, y - 2.0), Vector2(x + 3.0, y - 2.0),
					Vector2(x + w * 0.22, bottom), Vector2(x - w * 0.22, bottom),
				]), Color(edge.r, edge.g, edge.b, 0.045))
			&"gate":
				# Perimeter wall with a lit gate arch.
				draw_rect(Rect2(x0, y + h * 0.5, w, h * 0.5), col)
				draw_rect(Rect2(x0, y + h * 0.5, w, h * 0.08), dark)
				draw_rect(Rect2(x0 - 3.0, y, 5.0, h * 0.55), dark)
				draw_rect(Rect2(x0 + w - 2.0, y, 5.0, h * 0.55), dark)
				draw_rect(Rect2(x - w * 0.14, bottom - h * 0.4, w * 0.28, h * 0.4), dark)
				draw_line(Vector2(x - w * 0.14, bottom - h * 0.4), Vector2(x + w * 0.14, bottom - h * 0.4), accent, 1.4)
				draw_circle(Vector2(x0 - 0.5, y + h * 0.45), 1.8, accent)
				draw_circle(Vector2(x0 + w - 1.5, y + h * 0.45), 1.8, accent)
			&"tower":
				var top_w := w * 0.34
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, bottom), Vector2(x0 + w, bottom),
					Vector2(x0 + w * 0.5 + top_w * 0.5, y + h * 0.1), Vector2(x0 + w * 0.5 - top_w * 0.5, y + h * 0.1),
				]), col)
				draw_rect(Rect2(x0 + w * 0.4, y + h * 0.05, w * 0.2, h * 0.16), dark)
				for i in 3:
					_light(seed, i, x0 + w * (0.2 + i * 0.26), y + h * (0.35 + i * 0.2), w * 0.14, h * 0.09)
				draw_line(Vector2(x, y + h * 0.08), Vector2(x, y - 4.0), accent, 1.5)
				draw_circle(Vector2(x, y - 4.0), 1.8, accent)
			&"block":
				draw_rect(Rect2(x0, y, w, h), col)
				draw_rect(Rect2(x0, y, w, h * 0.12), dark)
				for r in 2:
					for c in 3:
						_light(seed, r * 3 + c, x0 + w * (0.12 + c * 0.28), y + h * (0.3 + r * 0.32), w * 0.12, h * 0.12)
				if _hash01(seed, 99) < 0.6:
					var rx := x0 + w * 0.2
					var rw := w * 0.24
					draw_rect(Rect2(rx, y - 5.0, rw, 6.0), dark)
			&"dome":
				draw_circle(Vector2(x, bottom), w * 0.5, col)
				draw_rect(Rect2(x0, bottom - 3.0, w, 3.0), dark)
				for i in 4:
					_light(seed, i, x + (i - 1.5) * w * 0.2, bottom - w * 0.36, w * 0.08, w * 0.18)
			&"antenna":
				draw_rect(Rect2(x0 + w * 0.4, bottom - 6.0, w * 0.2, 6.0), dark)
				draw_line(Vector2(x, bottom), Vector2(x, y), col, 2.5)
				draw_line(Vector2(x - w * 0.28, y + h * 0.45), Vector2(x + w * 0.28, y + h * 0.45), col, 2.0)
				draw_line(Vector2(x - w * 0.22, y + h * 0.7), Vector2(x + w * 0.22, y + h * 0.7), col, 1.6)
				_beacon(seed, x, y - 2.0)
			&"pylon":
				draw_line(Vector2(x0 + w * 0.12, bottom), Vector2(x - w * 0.08, y + h * 0.08), col, 2.5)
				draw_line(Vector2(x0 + w * 0.88, bottom), Vector2(x + w * 0.08, y + h * 0.08), col, 2.5)
				for i in 3:
					var by := bottom - h * (0.2 + i * 0.28)
					draw_line(Vector2(x - w * 0.35, by), Vector2(x + w * 0.35, by), col, 1.5)
					draw_circle(Vector2(x - w * 0.35, by), 1.6, accent)
					draw_circle(Vector2(x + w * 0.35, by), 1.6, accent)
				draw_circle(Vector2(x, y + h * 0.05), 2.0, accent)
			&"crystal":
				for i in 3:
					var cw := w * 0.28 * (1.0 - i * 0.22)
					var ch := h * (0.7 - i * 0.15)
					var cx := x + (i - 1) * w * 0.24
					var cy := bottom - ch * 0.2
					draw_colored_polygon(PackedVector2Array([
						Vector2(cx - cw * 0.5, bottom), Vector2(cx, cy), Vector2(cx + cw * 0.5, bottom),
					]), col)
					draw_line(Vector2(cx, cy), Vector2(cx, bottom), accent.lightened(0.4), 1.2)
				draw_rect(Rect2(x0, bottom - 3.0, w, 3.0), dark)
			&"crater":
				draw_circle(Vector2(x, bottom - h * 0.25), w * 0.42, dark.darkened(0.25))
				draw_arc(Vector2(x, bottom - h * 0.25), w * 0.42, PI, TAU, 12, accent, 1.6)
				draw_line(Vector2(x - w * 0.2, bottom - h * 0.5), Vector2(x + w * 0.25, bottom - h * 0.85), col, 2.0)
				draw_line(Vector2(x + w * 0.25, bottom - h * 0.85), Vector2(x + w * 0.25, bottom - h * 0.55), col, 2.0)
				_beacon(seed, x + w * 0.25, bottom - h * 0.9)
			&"pod":
				for i in 3:
					var pr := w * (0.3 - i * 0.08)
					var px := x + (i - 1) * w * 0.22
					var py := bottom - h * (0.45 - i * 0.12)
					draw_circle(Vector2(px, py), pr, col)
					draw_circle(Vector2(px + pr * 0.3, py - pr * 0.3), pr * 0.35, Color(0.35, 0.9, 0.6, 0.7))
				for i in 4:
					var gx := x + (i - 1.5) * w * 0.3
					draw_circle(Vector2(gx, bottom - 2.0), 1.6, Color(0.55, 1.0, 0.7, 0.8))
			&"crane":
				var pivot := Vector2(x + w * 0.1, bottom)
				var top_p := Vector2(x + w * 0.1, bottom - h)
				draw_line(pivot, top_p, col, 3.0)
				draw_line(top_p, Vector2(x + w * 0.95, bottom - h * 0.85), col, 2.5)
				draw_line(Vector2(x + w * 0.5, bottom), top_p, col, 2.0)
				draw_line(Vector2(x + w * 0.95, bottom - h * 0.85), Vector2(x + w * 0.95, bottom - h * 0.3), col, 1.5)
				draw_circle(Vector2(x + w * 0.95, bottom - h * 0.3), 2.0, accent)
				for i in 3:
					_beacon(seed + i, x + w * 0.5, bottom - h * (0.35 + i * 0.25))
			&"spire":
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, bottom), Vector2(x + w * 0.5, y), Vector2(x0 + w, bottom),
				]), col)
				draw_line(Vector2(x, bottom), Vector2(x, y + h * 0.1), accent, 1.5)
				for i in 3:
					var by := bottom - h * (0.25 + i * 0.24)
					draw_line(Vector2(x0 + w * 0.1, by), Vector2(x0 + w * 0.9, by), Color(edge.r, edge.g, edge.b, 0.4), 1.0)
				draw_circle(Vector2(x, y - 2.0), 2.0, accent)
			&"deck":
				draw_rect(Rect2(x0, y + h * 0.25, w, h * 0.75), col)
				draw_rect(Rect2(x0, y, w, h * 0.25), dark)
				for i in 4:
					draw_line(Vector2(x0 + w * (0.15 + i * 0.2), y + h * 0.4), Vector2(x0 + w * (0.35 + i * 0.2), y + h * 0.55), accent, 1.4)
				for i in 2:
					var sh := Vector2(x + (i - 0.5) * w * 0.4, y + h * 0.1)
					draw_colored_polygon(PackedVector2Array([
						sh + Vector2(-w * 0.07, 0), sh + Vector2(0, -h * 0.12), sh + Vector2(w * 0.07, 0),
					]), dark.lightened(0.15))
			&"junk":
				var pts := PackedVector2Array([
					Vector2(x0, bottom), Vector2(x0 + w * 0.1, bottom - h * 0.4),
					Vector2(x0 + w * 0.32, bottom - h * 0.22), Vector2(x0 + w * 0.5, bottom - h * 0.62),
					Vector2(x0 + w * 0.68, bottom - h * 0.2), Vector2(x0 + w * 0.9, bottom - h * 0.45),
					Vector2(x0 + w, bottom),
				])
				draw_colored_polygon(pts, col)
				for i in 5:
					draw_circle(Vector2(x0 + w * (0.15 + i * 0.18), bottom - h * (0.12 + _hash01(seed, i) * 0.3)), 1.8, dark.lightened(0.2))
				draw_line(Vector2(x + w * 0.3, bottom - h * 0.3), Vector2(x + w * 0.55, bottom - h * 0.75), accent, 2.0)
				draw_circle(Vector2(x + w * 0.55, bottom - h * 0.75), 1.8, accent)
			&"ruin":
				draw_rect(Rect2(x0, y + h * 0.2, w * 0.4, h * 0.8), col)
				draw_rect(Rect2(x0 + w * 0.6, y + h * 0.45, w * 0.4, h * 0.55), col.darkened(0.25))
				draw_line(Vector2(x0 + w * 0.4, y + h * 0.2), Vector2(x0 + w * 0.6, y + h * 0.2), accent, 2.0)
				for i in 3:
					draw_circle(Vector2(x + (i - 1) * w * 0.22, y + h * 0.5), 1.4, Color(edge.r, edge.g, edge.b, 0.35 + 0.3 * _hash01(seed, i)))
			_:
				draw_rect(Rect2(x0, y, w, h), col)
