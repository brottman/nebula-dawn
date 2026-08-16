extends Node2D
## Enemy-base flyover backdrop — the entire playfield is a scrolling
## industrial war-ground, drawn in parallax depth bands:
##   Atmosphere   0.06x — haze gradient, drifting smoke, sweeping searchlights
##   Far skyline  0.14x — dense distant refinery / antenna silhouettes
##   Mid base     0.38x — cranes, gantries, silos, towers (lit windows, smoke)
##   Near base    0.70x — launch pads, grounded ships, roads + moving vehicles
##   Tactical grid 1.0x — faint targeting grid where combat lives
##   Foreground   1.50x — metal debris, embers, smoke puffs above the action
## Every layer is procedurally drawn (no sprite assets) and loops forever.

const SPEED_SKY := 0.06
const SPEED_FAR := 0.14
const SPEED_MID := 0.38
const SPEED_NEAR := 0.7
const SPEED_GRID := 1.0
const SPEED_FG := 1.5

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _sky: _SkyLayer
var _far: _BandBase
var _mid: _BandBase
var _near: _NearBand
var _grid: _GridLayer
var _fg: _ForegroundLayer
var _rng := RandomNumberGenerator.new()
var _style: StringName = &"city"


func _ready() -> void:
	_rng.randomize()
	_sky = _SkyLayer.new()
	_sky.name = "Atmosphere"
	_sky.z_index = -40
	add_child(_sky)

	_far = _BandBase.new()
	_far.name = "FarSkyline"
	_far.z_index = -30
	_far.band_detail = 0
	_far.band_count = 16
	_far.w_range = Vector2(34.0, 72.0)
	_far.h_range = Vector2(28.0, 62.0)
	_far.wide_w = Vector2(60.0, 100.0)
	_far.wide_h = Vector2(24.0, 44.0)
	_far.tall_w = Vector2(16.0, 26.0)
	_far.tall_h = Vector2(42.0, 84.0)
	add_child(_far)

	_mid = _BandBase.new()
	_mid.name = "MidBase"
	_mid.z_index = -20
	_mid.band_detail = 1
	_mid.band_count = 12
	_mid.w_range = Vector2(60.0, 130.0)
	_mid.h_range = Vector2(46.0, 96.0)
	_mid.wide_w = Vector2(100.0, 180.0)
	_mid.wide_h = Vector2(42.0, 72.0)
	_mid.tall_w = Vector2(26.0, 44.0)
	_mid.tall_h = Vector2(74.0, 150.0)
	add_child(_mid)

	_near = _NearBand.new()
	_near.name = "NearBase"
	_near.z_index = -10
	_near.band_detail = 2
	_near.band_count = 7
	_near.w_range = Vector2(130.0, 260.0)
	_near.h_range = Vector2(100.0, 190.0)
	_near.wide_w = Vector2(210.0, 360.0)
	_near.wide_h = Vector2(90.0, 140.0)
	_near.tall_w = Vector2(44.0, 74.0)
	_near.tall_h = Vector2(150.0, 260.0)
	add_child(_near)

	_grid = _GridLayer.new()
	_grid.name = "TacticalGrid"
	_grid.z_index = -5
	add_child(_grid)

	_fg = _ForegroundLayer.new()
	_fg.name = "ForegroundDebris"
	_fg.z_as_relative = false
	_fg.z_index = 50
	add_child(_fg)

	var vp := get_viewport_rect().size
	_sky.setup(vp, tint, _rng)
	_far.setup(vp, tint, _rng)
	_mid.setup(vp, tint, _rng)
	_near.setup(vp, tint, _rng)
	_grid.setup(vp, tint, _rng)
	_fg.setup(vp, tint, _rng)
	get_viewport().size_changed.connect(_on_viewport_resized)
	set_style(_style)


func _on_viewport_resized() -> void:
	var vp := get_viewport_rect().size
	_sky.on_resize(vp)
	_far.on_resize(vp)
	_mid.on_resize(vp)
	_near.on_resize(vp)
	_grid.on_resize(vp)
	_fg.on_resize(vp)


func set_style(s: StringName) -> void:
	_style = s
	if _sky:
		_sky.set_style_name(s)
	if _far:
		_far.set_style(s)
	if _mid:
		_mid.set_style(s)
	if _near:
		_near.set_style(s)


func set_terrain(style: StringName) -> void:
	set_style(style)


func set_terrain_random() -> void:
	set_style(_BandBase.STYLE_KEYS[_rng.randi() % _BandBase.STYLE_KEYS.size()])


func set_tint(c: Color) -> void:
	tint = c
	_sky.tint = c
	_sky.queue_redraw()
	_far.tint = c
	_far.queue_redraw()
	_mid.tint = c
	_mid.queue_redraw()
	_near.tint = c
	_near.queue_redraw()
	_grid.tint = c
	_grid.queue_redraw()
	_fg.tint = c
	_fg.queue_redraw()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	_sky.tick(delta, scroll_speed * SPEED_SKY, vp)
	_far.tick(delta, scroll_speed * SPEED_FAR, vp)
	_mid.tick(delta, scroll_speed * SPEED_MID, vp)
	_near.tick(delta, scroll_speed * SPEED_NEAR, vp)
	_grid.tick(delta, scroll_speed * SPEED_GRID, vp)
	_fg.tick(delta, scroll_speed * SPEED_FG, vp)


# ---------------------------------------------------------------------------
# Atmosphere — 0.06x
# Full-screen haze gradient (hazy at altitude, dark near the ground),
# high drifting smoke from the base below, and sweeping searchlight beams.
# ---------------------------------------------------------------------------
class _SkyLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var _style: StringName = &"city"
	var clouds: Array[Vector3] = [] # x, y, radius
	var _rng: RandomNumberGenerator
	var _time: float = 0.0

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		clouds.clear()
		for i in 5:
			clouds.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(60.0, 130.0)))

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_style_name(s: StringName) -> void:
		_style = s
		queue_redraw()

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_time += delta
		for i in clouds.size():
			var c := clouds[i]
			c.y += speed * delta
			if c.y - c.z > vp.y + 40.0:
				c.y = -c.z - 40.0
				c.x = _rng.randf() * vp.x
			clouds[i] = c
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var pal: Dictionary = _BandBase.palette_for(_style, tint)
		var haze: Color = pal["haze"].lightened(0.38)
		var deep: Color = Color(pal["deep"].r, pal["deep"].g, pal["deep"].b, 1.0).darkened(0.22)
		for i in 12:
			var t := float(i) / 11.0
			draw_rect(Rect2(0.0, vp.y * i / 12.0, vp.x, vp.y / 12.0 + 1.0), haze.lerp(deep, t))
		# High smoke haze, tinted by the mission palette.
		for c in clouds:
			var col := haze.darkened(0.15)
			draw_circle(Vector2(c.x, c.y), c.z, Color(col.r, col.g, col.b, 0.045))
			draw_circle(Vector2(c.x + c.z * 0.3, c.y + c.z * 0.2), c.z * 0.6, Color(col.r, col.g, col.b, 0.03))
		# Searchlight sweep — skipped in flash-reduction mode.
		if not GameState.reduce_flashes:
			var beam_col := Color(0.95, 0.97, 1.0, 0.05)
			_beam(Vector2(vp.x * 0.22, -24.0), 0.55, vp.y * 1.15, beam_col)
			_beam(Vector2(vp.x * 0.78, -24.0), -0.55, vp.y * 1.15, beam_col)

	func _beam(origin: Vector2, base_angle: float, length: float, col: Color) -> void:
		var a := base_angle + sin(_time * 0.33 + origin.x * 0.01) * 0.24
		var dir := Vector2(sin(a), 1.0).normalized()
		var tip := origin + dir * length
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			origin + side * 5.0, origin - side * 5.0,
			tip - side * 46.0, tip + side * 46.0,
		]), col)
		draw_circle(origin, 4.0, Color(col.r, col.g, col.b, 0.6))


# ---------------------------------------------------------------------------
# Scrolling structure band — shared by far / mid / near base depths.
# ---------------------------------------------------------------------------
class _BandBase extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var style: StringName = &"city"
	var band_detail: int = 1
	var band_count: int = 12
	var w_range := Vector2(60.0, 130.0)
	var h_range := Vector2(46.0, 96.0)
	var wide_w := Vector2(100.0, 180.0)
	var wide_h := Vector2(42.0, 72.0)
	var tall_w := Vector2(26.0, 44.0)
	var tall_h := Vector2(74.0, 150.0)
	var structures: Array[Dictionary] = []
	var _rng: RandomNumberGenerator
	var _time: float = 0.0
	var _scroll_accum: float = 0.0

	const WIDE_KINDS := [&"barracks", &"hangar", &"deck", &"gate", &"silo", &"block",
		&"refinery", &"fuel_depot", &"landing_pad", &"junk", &"ruin", &"crater",
		&"pod", &"dome", &"crystal"]
	const TALL_KINDS := [&"watchtower", &"radar_dish", &"antenna", &"spire", &"pylon",
		&"floodlight", &"stack", &"cooling_tower", &"gantry", &"derrick",
		&"missile_silo", &"control_tower", &"crane", &"water_tower", &"aa_turret"]

	const STYLES := {
		&"city": {
			"kinds": [&"barracks", &"block", &"hangar", &"watchtower", &"radar_dish", &"gate", &"control_tower", &"silo"],
			"haze": Color(0.30, 0.26, 0.20),
			"deep": Color(0.05, 0.04, 0.03),
			"edge": Color(1.0, 0.62, 0.28),
			"detail": &"runway",
		},
		&"mines": {
			"kinds": [&"silo", &"watchtower", &"barracks", &"crater", &"gate", &"derrick", &"stack", &"fuel_depot"],
			"haze": Color(0.26, 0.22, 0.18),
			"deep": Color(0.04, 0.035, 0.03),
			"edge": Color(1.0, 0.75, 0.35),
			"detail": &"road",
		},
		&"biolum": {
			"kinds": [&"hangar", &"pod", &"dome", &"silo", &"gate", &"cooling_tower", &"antenna", &"crystal"],
			"haze": Color(0.16, 0.22, 0.20),
			"deep": Color(0.02, 0.05, 0.04),
			"edge": Color(0.55, 1.0, 0.75),
			"detail": &"glow",
		},
		&"factory": {
			"kinds": [&"hangar", &"crane", &"block", &"silo", &"watchtower", &"floodlight", &"refinery", &"stack", &"gantry"],
			"haze": Color(0.22, 0.24, 0.26),
			"deep": Color(0.035, 0.045, 0.05),
			"edge": Color(0.45, 0.9, 1.0),
			"detail": &"road",
		},
		&"fleet": {
			"kinds": [&"deck", &"control_tower", &"hangar", &"aa_turret", &"radar_dish", &"gate", &"landing_pad", &"gantry"],
			"haze": Color(0.18, 0.22, 0.30),
			"deep": Color(0.03, 0.04, 0.07),
			"edge": Color(0.4, 0.7, 1.0),
			"detail": &"runway",
		},
		&"mirror": {
			"kinds": [&"crystal", &"gate", &"watchtower", &"dome", &"floodlight", &"antenna", &"spire", &"radar_dish"],
			"haze": Color(0.16, 0.24, 0.30),
			"deep": Color(0.02, 0.045, 0.06),
			"edge": Color(0.55, 0.9, 1.0),
			"detail": &"glow",
		},
		&"storm": {
			"kinds": [&"pylon", &"silo", &"watchtower", &"barracks", &"aa_turret", &"missile_silo", &"derrick", &"stack"],
			"haze": Color(0.14, 0.20, 0.28),
			"deep": Color(0.02, 0.035, 0.06),
			"edge": Color(0.55, 0.8, 1.0),
			"detail": &"road",
		},
		&"wake": {
			"kinds": [&"ruin", &"gate", &"barracks", &"radar_dish", &"water_tower", &"spire", &"junk"],
			"haze": Color(0.18, 0.16, 0.26),
			"deep": Color(0.03, 0.025, 0.05),
			"edge": Color(0.7, 0.55, 1.0),
			"detail": &"none",
		},
		&"scrap": {
			"kinds": [&"junk", &"hangar", &"crane", &"aa_turret", &"barracks", &"gate", &"derrick", &"stack"],
			"haze": Color(0.26, 0.20, 0.14),
			"deep": Color(0.05, 0.035, 0.02),
			"edge": Color(1.0, 0.6, 0.3),
			"detail": &"road",
		},
		&"flare": {
			"kinds": [&"spire", &"gate", &"control_tower", &"aa_turret", &"floodlight", &"stack", &"cooling_tower", &"refinery"],
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

	static func palette_for(s: StringName, t: Color) -> Dictionary:
		var pal: Dictionary = STYLES.get(s, STYLES[&"city"])
		var haze: Color = Color(pal["haze"]).lerp(t, 0.22)
		var deep: Color = Color(pal["deep"]).lerp(t.darkened(0.35), 0.3)
		return {"haze": haze, "deep": deep, "edge": Color(pal["edge"]), "detail": pal["detail"]}

	func setup(_vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_style(s: StringName) -> void:
		style = s
		structures.clear()
		_scroll_accum = 0.0
		var vp := get_viewport_rect().size
		for i in band_count:
			structures.append(_new_structure(vp, true))
		queue_redraw()

	func _palette() -> Dictionary:
		return palette_for(style, tint)

	func _new_structure(vp: Vector2, prefill: bool = false) -> Dictionary:
		var pal: Dictionary = _palette()
		var kinds: Array = pal.get("kinds", [&"block"])
		# Prefer wide kinds on wide-heavy styles but keep variety.
		var kind: StringName = kinds[_rng.randi() % kinds.size()]
		var wide := kind in WIDE_KINDS
		var tall := kind in TALL_KINDS
		var w := _rng.randf_range(w_range.x, w_range.y)
		var h := _rng.randf_range(h_range.x, h_range.y)
		if wide:
			w = _rng.randf_range(wide_w.x, wide_w.y)
			h = _rng.randf_range(wide_h.x, wide_h.y)
		if tall:
			w = _rng.randf_range(tall_w.x, tall_w.y)
			h = _rng.randf_range(tall_h.x, tall_h.y)
		return {
			"kind": kind,
			"x": _rng.randf_range(24.0, vp.x - 24.0),
			"w": w,
			"h": h,
			"y": -h - _rng.randf_range(0.0, vp.y * 0.9) if prefill else -h - _rng.randf_range(0.0, 120.0),
			"seed": _rng.randi(),
			"grow": _rng.randf_range(0.8, 1.3),
		}

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_time += delta
		_scroll_accum += speed * delta
		for i in structures.size():
			var s: Dictionary = structures[i]
			s["y"] = float(s["y"]) + speed * delta
			if float(s["y"]) - float(s["h"]) * 0.5 > vp.y + 40.0:
				structures[i] = _new_structure(vp)
			else:
				structures[i] = s
		queue_redraw()

	func _structure_color(y: float, vp_h: float) -> Color:
		var t := clampf(y / maxf(1.0, vp_h), 0.0, 1.0)
		var pal := _palette()
		var c: Color = pal["haze"].lerp(pal["deep"], t)
		if band_detail == 0:
			c = c.lerp(pal["haze"], 0.3)
		return c

	func _draw() -> void:
		var vp := get_viewport_rect().size
		if vp.y <= 0.0:
			return
		var pal := _palette()
		var edge: Color = pal["edge"]
		for s in structures:
			_paint_structure(s, vp, edge)

	func _paint_structure(s: Dictionary, vp: Vector2, edge: Color) -> void:
		var kind: StringName = s["kind"]
		var x: float = s["x"]
		var w: float = float(s["w"]) * float(s["grow"])
		var h: float = float(s["h"]) * float(s["grow"])
		var y: float = float(s["y"])
		if y > vp.y or y + h < -40.0:
			return
		var col := _structure_color(y, vp.y)
		var seed: int = s["seed"]
		_paint(kind, x, y, w, h, seed, col, edge, band_detail, _time)

	# ------------------------------------------------------------------
	# Structure painter — one procedural renderer for every band depth.
	# ------------------------------------------------------------------
	func _paint(kind: StringName, x: float, y: float, w: float, h: float, seed: int,
			col: Color, edge: Color, detail: int, t: float) -> void:
		var x0 := x - w * 0.5
		var bottom := y + h
		var dark := col.darkened(0.45)
		var accent := Color(edge.r, edge.g, edge.b, 0.9)
		var lit := detail >= 1
		match kind:
			&"barracks":
				draw_rect(Rect2(x0, y + h * 0.18, w, h * 0.82), col)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, y + h * 0.18), Vector2(x + w * 0.5, y), Vector2(x0 + w, y + h * 0.18),
				]), dark)
				draw_line(Vector2(x - w * 0.4, y + h * 0.16), Vector2(x + w * 0.4, y + h * 0.16), accent, 1.2)
				draw_rect(Rect2(x - w * 0.08, bottom - h * 0.42, w * 0.16, h * 0.42), dark)
				if lit:
					for i in 6:
						_light(seed, i, x0 + w * (0.1 + i * 0.13), y + h * 0.32, w * 0.07, h * 0.12)
				if detail >= 2:
					draw_rect(Rect2(x0 + w * 0.38, y + h * 0.05, w * 0.08, h * 0.12), dark)
			&"hangar":
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
				if detail >= 2:
					_hazard(x - w * 0.16, bottom - h * 0.52, w * 0.32, h * 0.09, edge)
				if lit:
					draw_rect(Rect2(x - w * 0.16, bottom - h * 0.52, w * 0.32, h * 0.1), Color(edge.r, edge.g, edge.b, 0.3))
					draw_circle(Vector2(x - w * 0.16, bottom - h * 0.52), 1.6, accent)
					draw_circle(Vector2(x + w * 0.16, bottom - h * 0.52), 1.6, accent)
			&"radar_dish":
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
				draw_rect(Rect2(x0, y + h * 0.34, w, h * 0.66), col)
				draw_rect(Rect2(x0, y + h * 0.34, w, h * 0.14), dark)
				draw_circle(Vector2(x, y + h * 0.48), w * 0.17, dark.darkened(0.2))
				draw_arc(Vector2(x, y + h * 0.48), w * 0.17, 0.0, TAU, 12, accent, 1.4)
				draw_line(Vector2(x, y + h * 0.48), Vector2(x - w * 0.16, y + h * 0.12), col, 2.4)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.16, y + h * 0.18), Vector2(x - w * 0.16, y + h * 0.08),
					Vector2(x - w * 0.1, y + h * 0.12),
				]), dark)
				if detail >= 2:
					_hazard(x0, y + h * 0.34, w, h * 0.05, edge)
				_beacon(seed, x - w * 0.16, y + h * 0.05)
			&"watchtower":
				draw_line(Vector2(x - w * 0.28, bottom), Vector2(x - w * 0.1, y + h * 0.26), dark, 2.2)
				draw_line(Vector2(x + w * 0.28, bottom), Vector2(x + w * 0.1, y + h * 0.26), dark, 2.2)
				draw_line(Vector2(x - w * 0.16, bottom), Vector2(x - w * 0.04, y + h * 0.26), dark, 1.4)
				draw_line(Vector2(x + w * 0.16, bottom), Vector2(x + w * 0.04, y + h * 0.26), dark, 1.4)
				draw_rect(Rect2(x - w * 0.24, y, w * 0.48, h * 0.28), col)
				draw_rect(Rect2(x - w * 0.24, y + h * 0.28, w * 0.48, h * 0.05), dark)
				if lit:
					_light(seed, 1, x - w * 0.14, y + h * 0.06, w * 0.28, h * 0.14)
				draw_line(Vector2(x - w * 0.28, y), Vector2(x + w * 0.28, y), dark, 1.6)
				draw_circle(Vector2(x, y + h * 0.26), 2.0, accent)
				if detail >= 2:
					draw_colored_polygon(PackedVector2Array([
						Vector2(x - w * 0.1, y + h * 0.3), Vector2(x + w * 0.1, y + h * 0.3),
						Vector2(x + w * 0.18, y + h * 0.62), Vector2(x - w * 0.18, y + h * 0.62),
					]), Color(edge.r, edge.g, edge.b, 0.07))
			&"control_tower":
				draw_rect(Rect2(x - w * 0.14, y + h * 0.28, w * 0.28, h * 0.72), col)
				draw_rect(Rect2(x - w * 0.3, y, w * 0.6, h * 0.3), col)
				if lit:
					draw_rect(Rect2(x - w * 0.26, y + h * 0.08, w * 0.52, h * 0.1), Color(edge.r, edge.g, edge.b, 0.55))
				draw_line(Vector2(x - w * 0.3, y), Vector2(x + w * 0.3, y), dark, 1.6)
				draw_line(Vector2(x, y), Vector2(x, y - h * 0.08), col, 1.6)
				draw_circle(Vector2(x, y - h * 0.08), 1.8, accent)
				_beacon(seed, x - w * 0.3, y + h * 0.05)
			&"aa_turret":
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.4, bottom), Vector2(x + w * 0.4, bottom),
					Vector2(x + w * 0.2, y + h * 0.62), Vector2(x - w * 0.2, y + h * 0.62),
				]), dark)
				draw_rect(Rect2(x - w * 0.14, y + h * 0.5, w * 0.28, h * 0.14), col)
				draw_line(Vector2(x - w * 0.08, y + h * 0.5), Vector2(x - w * 0.22, y + h * 0.1), col, 2.2)
				draw_line(Vector2(x + w * 0.08, y + h * 0.5), Vector2(x + w * 0.22, y + h * 0.1), col, 2.2)
				if lit:
					draw_circle(Vector2(x - w * 0.22, y + h * 0.1), 1.6, accent)
					draw_circle(Vector2(x + w * 0.22, y + h * 0.1), 1.6, accent)
				_beacon(seed, x, y + h * 0.5)
			&"water_tower":
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
				if lit:
					draw_circle(Vector2(x, y), 1.6, accent)
			&"floodlight":
				draw_line(Vector2(x, bottom), Vector2(x, y), col, 2.0)
				draw_rect(Rect2(x - 2.5, y - 3.0, 5.0, 5.0), dark)
				draw_circle(Vector2(x, y - 3.0), 2.0, Color(1.0, 0.9, 0.6, 0.9))
				if detail >= 2:
					draw_colored_polygon(PackedVector2Array([
						Vector2(x - 3.0, y - 2.0), Vector2(x + 3.0, y - 2.0),
						Vector2(x + w * 0.22, bottom), Vector2(x - w * 0.22, bottom),
					]), Color(edge.r, edge.g, edge.b, 0.045))
			&"gate":
				draw_rect(Rect2(x0, y + h * 0.5, w, h * 0.5), col)
				draw_rect(Rect2(x0, y + h * 0.5, w, h * 0.08), dark)
				draw_rect(Rect2(x0 - 3.0, y, 5.0, h * 0.55), dark)
				draw_rect(Rect2(x0 + w - 2.0, y, 5.0, h * 0.55), dark)
				draw_rect(Rect2(x - w * 0.14, bottom - h * 0.4, w * 0.28, h * 0.4), dark)
				if lit:
					draw_line(Vector2(x - w * 0.14, bottom - h * 0.4), Vector2(x + w * 0.14, bottom - h * 0.4), accent, 1.4)
					draw_circle(Vector2(x0 - 0.5, y + h * 0.45), 1.8, accent)
					draw_circle(Vector2(x0 + w - 1.5, y + h * 0.45), 1.8, accent)
				if detail >= 2:
					_hazard(x - w * 0.14, bottom - h * 0.4, w * 0.28, h * 0.05, edge)
			&"tower":
				var top_w := w * 0.34
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, bottom), Vector2(x0 + w, bottom),
					Vector2(x0 + w * 0.5 + top_w * 0.5, y + h * 0.1), Vector2(x0 + w * 0.5 - top_w * 0.5, y + h * 0.1),
				]), col)
				draw_rect(Rect2(x0 + w * 0.4, y + h * 0.05, w * 0.2, h * 0.16), dark)
				if lit:
					for i in 3:
						_light(seed, i, x0 + w * (0.2 + i * 0.26), y + h * (0.35 + i * 0.2), w * 0.14, h * 0.09)
				draw_line(Vector2(x, y + h * 0.08), Vector2(x, y - 4.0), accent, 1.5)
				draw_circle(Vector2(x, y - 4.0), 1.8, accent)
			&"block":
				draw_rect(Rect2(x0, y, w, h), col)
				draw_rect(Rect2(x0, y, w, h * 0.12), dark)
				if lit:
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
				if lit:
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
					if lit:
						draw_circle(Vector2(px + pr * 0.3, py - pr * 0.3), pr * 0.35, Color(0.35, 0.9, 0.6, 0.7))
				if lit:
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
				if lit:
					draw_circle(Vector2(x + w * 0.95, bottom - h * 0.3), 2.0, accent)
					for i in 3:
						_beacon(seed + i, x + w * 0.5, bottom - h * (0.35 + i * 0.25))
			&"spire":
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, bottom), Vector2(x + w * 0.5, y), Vector2(x0 + w, bottom),
				]), col)
				draw_line(Vector2(x, bottom), Vector2(x, y + h * 0.1), accent, 1.5)
				if lit:
					for i in 3:
						var by := bottom - h * (0.25 + i * 0.24)
						draw_line(Vector2(x0 + w * 0.1, by), Vector2(x0 + w * 0.9, by), Color(edge.r, edge.g, edge.b, 0.4), 1.0)
				draw_circle(Vector2(x, y - 2.0), 2.0, accent)
			&"deck":
				draw_rect(Rect2(x0, y + h * 0.25, w, h * 0.75), col)
				draw_rect(Rect2(x0, y, w, h * 0.25), dark)
				if lit:
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
				if lit:
					for i in 5:
						draw_circle(Vector2(x0 + w * (0.15 + i * 0.18), bottom - h * (0.12 + _hash01(seed, i) * 0.3)), 1.8, dark.lightened(0.2))
					draw_line(Vector2(x + w * 0.3, bottom - h * 0.3), Vector2(x + w * 0.55, bottom - h * 0.75), accent, 2.0)
					draw_circle(Vector2(x + w * 0.55, bottom - h * 0.75), 1.8, accent)
			&"ruin":
				draw_rect(Rect2(x0, y + h * 0.2, w * 0.4, h * 0.8), col)
				draw_rect(Rect2(x0 + w * 0.6, y + h * 0.45, w * 0.4, h * 0.55), col.darkened(0.25))
				draw_line(Vector2(x0 + w * 0.4, y + h * 0.2), Vector2(x0 + w * 0.6, y + h * 0.2), accent, 2.0)
				if lit:
					for i in 3:
						draw_circle(Vector2(x + (i - 1) * w * 0.22, y + h * 0.5), 1.4, Color(edge.r, edge.g, edge.b, 0.35 + 0.3 * _hash01(seed, i)))
			&"refinery":
				# Twin storage tanks + pipe runs + vent flame.
				for i in 2:
					var tx := x + (i - 0.5) * w * 0.3
					var tw := w * 0.22
					var th := h * 0.62
					var ty := bottom - th
					draw_rect(Rect2(tx - tw * 0.5, ty, tw, th), col)
					draw_arc(Vector2(tx, ty), tw * 0.5, PI, TAU, 12, col.darkened(0.15), 1.2)
					draw_rect(Rect2(tx - tw * 0.5, ty, tw, th * 0.08), dark)
					for r in 3:
						draw_line(Vector2(tx - tw * 0.5, ty + th * (0.25 + r * 0.25)), Vector2(tx + tw * 0.5, ty + th * (0.25 + r * 0.25)), dark, 1.0)
				draw_line(Vector2(x - w * 0.16, bottom - h * 0.3), Vector2(x + w * 0.16, bottom - h * 0.3), dark, 2.0)
				draw_line(Vector2(x - w * 0.16, bottom - h * 0.3), Vector2(x - w * 0.16, bottom - h * 0.55), dark, 1.6)
				draw_line(Vector2(x + w * 0.16, bottom - h * 0.3), Vector2(x + w * 0.16, bottom - h * 0.55), dark, 1.6)
				if lit:
					_flame(seed, x, y + h * 0.12, t, w * 0.1, h * 0.1, edge)
					_light(seed, 7, x - w * 0.3, y + h * 0.3, w * 0.08, h * 0.1)
					_light(seed, 8, x + w * 0.22, y + h * 0.45, w * 0.08, h * 0.1)
			&"stack":
				draw_rect(Rect2(x - w * 0.22, y, w * 0.44, h), col)
				draw_rect(Rect2(x - w * 0.26, y, w * 0.52, h * 0.06), dark)
				draw_rect(Rect2(x - w * 0.26, bottom - h * 0.05, w * 0.52, h * 0.05), dark)
				if detail >= 2:
					_hazard(x - w * 0.26, y + h * 0.2, w * 0.52, h * 0.05, edge)
				if lit:
					_smoke(seed, x, y, t, w * 0.09)
			&"cooling_tower":
				# Hyperboloid silhouette built from arcs.
				var pts := PackedVector2Array()
				var n := 14
				for i in n + 1:
					var tt := float(i) / float(n)
					var px := x + sin(tt * PI) * w * 0.5
					var py := bottom - tt * h
					pts.append(Vector2(px, py))
				draw_colored_polygon(pts + PackedVector2Array([Vector2(x + w * 0.5, bottom), Vector2(x - w * 0.5, bottom)]), col)
				draw_arc(Vector2(x, y + h * 0.28), w * 0.4, PI, TAU, 12, dark, 1.4)
				if lit:
					_smoke(seed + 3, x, y + h * 0.06, t, w * 0.13)
			&"gantry":
				# Launch gantry A-frame with cross arms and floodlights.
				draw_line(Vector2(x - w * 0.4, bottom), Vector2(x + w * 0.12, y), dark, 3.0)
				draw_line(Vector2(x + w * 0.4, bottom), Vector2(x - w * 0.12, y), dark, 3.0)
				draw_line(Vector2(x - w * 0.2, bottom), Vector2(x + w * 0.28, y + h * 0.1), col, 2.0)
				draw_line(Vector2(x + w * 0.2, bottom), Vector2(x - w * 0.28, y + h * 0.1), col, 2.0)
				for i in 3:
					var by := bottom - h * (0.25 + i * 0.25)
					draw_line(Vector2(x - w * 0.3, by), Vector2(x + w * 0.3, by), col, 1.8)
				draw_rect(Rect2(x - w * 0.14, y + h * 0.05, w * 0.28, h * 0.09), dark)
				if lit:
					_light(seed, 2, x - w * 0.09, y + h * 0.06, w * 0.18, h * 0.05)
					_beacon(seed, x, y - 2.0)
			&"derrick":
				draw_line(Vector2(x - w * 0.34, bottom), Vector2(x, y), col, 2.5)
				draw_line(Vector2(x + w * 0.34, bottom), Vector2(x, y), col, 2.5)
				for i in 3:
					var by := bottom - h * (0.2 + i * 0.26)
					draw_line(Vector2(x - w * 0.24, by), Vector2(x + w * 0.24, by), col, 1.4)
					draw_line(Vector2(x, y), Vector2(x - w * 0.18, by), dark, 1.2)
				draw_rect(Rect2(x - w * 0.1, y + h * 0.06, w * 0.2, h * 0.06), dark)
				if lit:
					_flame(seed, x, y, t, w * 0.08, h * 0.07, edge)
			&"missile_silo":
				draw_rect(Rect2(x0, y + h * 0.4, w, h * 0.6), col)
				draw_rect(Rect2(x0, y + h * 0.4, w, h * 0.08), dark)
				draw_rect(Rect2(x - w * 0.12, y + h * 0.06, w * 0.24, h * 0.36), dark.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - w * 0.06, y + h * 0.06), Vector2(x + w * 0.06, y + h * 0.06), Vector2(x, y),
				]), dark.lightened(0.1))
				if detail >= 2:
					_hazard(x0, y + h * 0.4, w, h * 0.05, edge)
				if lit:
					_beacon(seed, x - w * 0.2, y + h * 0.45)
					_beacon(seed + 1, x + w * 0.2, y + h * 0.45)
			&"landing_pad":
				draw_rect(Rect2(x0, y + h * 0.55, w, h * 0.45), col.darkened(0.08))
				draw_rect(Rect2(x0, y + h * 0.55, w, h * 0.04), dark)
				if lit:
					for i in 5:
						var px := x0 + w * (0.12 + i * 0.19)
						var blink := 0.5 + 0.5 * sin(t * 3.0 + float(seed + i))
						draw_circle(Vector2(px, y + h * 0.55), 1.6, Color(edge.r, edge.g, edge.b, 0.4 + 0.6 * blink))
				# Parked fighter silhouette on the pad.
				var fx := x + w * 0.12
				var fy := y + h * 0.7
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - w * 0.18, fy), Vector2(fx - w * 0.1, fy - h * 0.16),
					Vector2(fx + w * 0.14, fy - h * 0.2), Vector2(fx + w * 0.24, fy - h * 0.05),
					Vector2(fx + w * 0.2, fy),
				]), dark)
				if lit:
					draw_circle(Vector2(fx + w * 0.14, fy - h * 0.05), 1.4, Color(1.0, 0.5, 0.3, 0.8))
				# Service crane.
				draw_line(Vector2(x - w * 0.42, bottom), Vector2(x - w * 0.42, y + h * 0.5), dark, 2.0)
				draw_line(Vector2(x - w * 0.42, y + h * 0.5), Vector2(x + w * 0.3, y + h * 0.5), col, 1.8)
				draw_line(Vector2(x + w * 0.3, y + h * 0.5), Vector2(x + w * 0.3, y + h * 0.62), dark, 1.2)
			&"fuel_depot":
				for i in 3:
					var tx := x + (i - 1) * w * 0.24
					var tw := w * 0.16
					var th := h * 0.8
					var ty := bottom - th
					draw_rect(Rect2(tx - tw * 0.5, ty, tw, th), col)
					draw_arc(Vector2(tx, ty), tw * 0.5, PI, TAU, 10, col.darkened(0.15), 1.2)
					draw_rect(Rect2(tx - tw * 0.5, ty + th * 0.85, tw, th * 0.15), dark)
				draw_line(Vector2(x - w * 0.34, bottom - h * 0.75), Vector2(x + w * 0.34, bottom - h * 0.75), dark, 1.6)
				draw_line(Vector2(x - w * 0.34, bottom - h * 0.45), Vector2(x + w * 0.34, bottom - h * 0.45), dark, 1.6)
				if detail >= 2:
					_hazard(x - w * 0.4, bottom - h * 0.12, w * 0.8, h * 0.04, edge)
				if lit:
					_light(seed, 5, x - w * 0.3, bottom - h * 0.62, w * 0.06, h * 0.08)
					_light(seed, 6, x + w * 0.24, bottom - h * 0.62, w * 0.06, h * 0.08)
			_:
				draw_rect(Rect2(x0, y, w, h), col)

	# --- small detail helpers -------------------------------------------------
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

	func _hazard(x: float, y: float, w: float, h: float, edge: Color) -> void:
		## Yellow/black warning stripe band.
		draw_rect(Rect2(x, y, w, h), Color(0.06, 0.06, 0.05, 0.85))
		var n := int(w / 10.0) + 1
		for i in n:
			var sx := x + i * 10.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx, y + h), Vector2(sx + 5.0, y + h), Vector2(sx + 10.0, y), Vector2(sx + 5.0, y),
			]), Color(edge.r, edge.g, edge.b, 0.5))

	func _smoke(seed: int, x: float, y: float, t: float, scale: float) -> void:
		## Rising smoke puffs from a stack — deterministic per structure.
		for i in 4:
			var rise := fmod(t * 13.0 + float(seed % 7) * 0.7 + float(i) * 0.55, 5.5)
			var cy := y - rise * 12.0 * scale
			var cx := x + sin(t * 1.3 + float(seed) + float(i) * 1.7) * (3.0 + rise * 4.0)
			var r := (5.0 + rise * 6.0) * scale
			var a := 0.20 * (1.0 - rise / 5.5) * scale
			draw_circle(Vector2(cx, cy), r, Color(0.5, 0.48, 0.44, a))

	func _flame(seed: int, x: float, y: float, t: float, w: float, h: float, edge: Color) -> void:
		## Flickering vent flame.
		if GameState.reduce_flashes:
			draw_circle(Vector2(x, y + h * 0.4), w * 0.5, Color(edge.r, edge.g, edge.b, 0.5))
			return
		var f := 0.75 + 0.25 * sin(t * 11.0 + float(seed))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w, y + h), Vector2(x + w, y + h),
			Vector2(x + w * 0.4 * f, y), Vector2(x - w * 0.4 * f, y),
		]), Color(1.0, 0.55, 0.2, 0.8))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.4, y + h), Vector2(x + w * 0.4, y + h),
			Vector2(x, y - h * 1.2 * f),
		]), Color(1.0, 0.9, 0.5, 0.9))


# ---------------------------------------------------------------------------
# Near base band — big close structures plus roads, vehicles, heat shimmer.
# ---------------------------------------------------------------------------
class _NearBand extends _BandBase:
	var vehicles: Array[Dictionary] = []

	func set_style(s: StringName) -> void:
		vehicles.clear()
		var vp := get_viewport_rect().size
		for i in 6:
			var lane := (i % 2 == 0)
			vehicles.append({
				"x": vp.x * (0.14 if lane else 0.86),
				"y": -30.0 - _rng.randf() * vp.y * 0.7,
				"lane": lane,
				"seed": _rng.randi(),
				"w": _rng.randf_range(30.0, 46.0),
				"h": _rng.randf_range(16.0, 24.0),
				"tank": _rng.randf() < 0.45,
			})
		super.set_style(s)

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		super.tick(delta, speed, vp)
		for i in vehicles.size():
			var v: Dictionary = vehicles[i]
			v["y"] = float(v["y"]) + speed * delta
			if float(v["y"]) > vp.y + 40.0:
				v["y"] = -30.0 - _rng.randf_range(0.0, 200.0)
				v["seed"] = _rng.randi()
				v["w"] = _rng.randf_range(30.0, 46.0)
				v["h"] = _rng.randf_range(16.0, 24.0)
				v["tank"] = _rng.randf() < 0.45
			vehicles[i] = v

	func _draw() -> void:
		var vp := get_viewport_rect().size
		if vp.y <= 0.0:
			return
		var pal := _palette()
		var edge: Color = pal["edge"]
		_draw_ground_detail(vp, pal, edge)
		for s in structures:
			_paint_structure(s, vp, edge)
		for v in vehicles:
			_draw_vehicle(v, pal, edge)
		_draw_heat(vp)

	func _draw_ground_detail(vp: Vector2, pal: Dictionary, edge: Color) -> void:
		## Base-floor markings scrolling with the world.
		var detail: StringName = pal.get("detail", &"none")
		var light := Color(edge.r, edge.g, edge.b, 0.4)
		var faint := Color(edge.r, edge.g, edge.b, 0.13)
		var dash := 60.0
		var off := fmod(_scroll_accum, dash)
		# Road lanes always exist on a working base.
		for rx in [vp.x * 0.14, vp.x * 0.86]:
			draw_rect(Rect2(rx - 7.0, 0.0, 14.0, vp.y), Color(pal["deep"].r, pal["deep"].g, pal["deep"].b, 0.55))
			for y in range(-60, int(vp.y) + 60, int(dash)):
				var dy := float(y) + off
				draw_rect(Rect2(rx - 1.5, dy, 3.0, 20.0), light)
				draw_circle(Vector2(rx - 10.0, dy + 10.0), 1.4, faint)
				draw_circle(Vector2(rx + 10.0, dy + 10.0), 1.4, faint)
		match detail:
			&"runway":
				var cx := vp.x * 0.5
				for y in range(-60, int(vp.y) + 60, int(dash)):
					var dy := ground_abs(off, float(y))
					draw_rect(Rect2(cx - 2.5, dy, 5.0, 26.0), light)
					draw_circle(Vector2(cx - 38.0, dy + 13.0), 1.5, faint)
					draw_circle(Vector2(cx + 38.0, dy + 13.0), 1.5, faint)
			&"glow":
				for i in 10:
					var gx := fmod(float(_hash01(int(_scroll_accum * 0.5), i)) * vp.x + off * 0.4, vp.x)
					var gy := fmod(float(_hash01(7, i * 3)) * vp.y + off, vp.y)
					draw_circle(Vector2(gx, gy), 1.8, faint)
					draw_circle(Vector2(gx, gy), 4.0, Color(edge.r, edge.g, edge.b, 0.06))
			_:
				pass

	func ground_abs(off: float, y: float) -> float:
		return y + off

	func _draw_vehicle(v: Dictionary, pal: Dictionary, edge: Color) -> void:
		var x := float(v["x"]) + sin(_time * 0.7 + float(v["seed"])) * 4.0
		var y := float(v["y"])
		var w := float(v["w"])
		var h := float(v["h"])
		var body := Color(pal["deep"].r, pal["deep"].g, pal["deep"].b, 1.0).darkened(0.35)
		if bool(v["tank"]):
			# Tracked tank driving down the lane.
			draw_rect(Rect2(x - w * 0.3, y - h * 0.3, w * 0.6, h * 0.6), body.darkened(0.3))
			draw_rect(Rect2(x - w * 0.2, y - h * 0.45, w * 0.4, h * 0.3), body)
			draw_circle(Vector2(x, y - h * 0.45), w * 0.14, body.darkened(0.2))
			draw_line(Vector2(x, y - h * 0.45), Vector2(x, y - h * 0.85), body, w * 0.06)
			_draw_headlight(x, y, w, edge)
		else:
			# Supply truck: cab + box.
			draw_rect(Rect2(x - w * 0.28, y - h * 0.5, w * 0.2, h * 0.5), body)
			draw_rect(Rect2(x + w * 0.0, y - h * 0.6, w * 0.34, h * 0.6), body.darkened(0.15))
			draw_circle(Vector2(x - w * 0.18, y + h * 0.35), h * 0.12, Color(0.08, 0.08, 0.1))
			draw_circle(Vector2(x + w * 0.14, y + h * 0.35), h * 0.12, Color(0.08, 0.08, 0.1))
			_draw_headlight(x, y, w, edge)

	func _draw_headlight(x: float, y: float, w: float, edge: Color) -> void:
		var beam := Color(edge.r, edge.g, edge.b, 0.12)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.16, y), Vector2(x + w * 0.16, y),
			Vector2(x + w * 0.34, y + w * 1.1), Vector2(x - w * 0.34, y + w * 1.1),
		]), beam)
		draw_circle(Vector2(x, y), 1.5, Color(edge.r, edge.g, edge.b, 0.9))

	func _draw_heat(vp: Vector2) -> void:
		if GameState.reduce_flashes:
			return
		for i in 3:
			var y0 := vp.y * (0.72 + float(i) * 0.1)
			var x0 := vp.x * (0.2 + float(i) * 0.25)
			var width := 220.0 + float(i) * 60.0
			var amp := 3.0 + float(i) * 2.0
			var pts := PackedVector2Array()
			var steps := 14
			for j in steps + 1:
				var px := x0 + width * float(j) / float(steps) - width * 0.5
				var py := y0 + sin(_time * 2.4 + float(i) * 2.1 + float(j) * 0.55) * amp
				pts.append(Vector2(px, py))
			draw_polyline(pts, Color(0.92, 0.95, 1.0, 0.05), 1.6)


# ---------------------------------------------------------------------------
# Tactical grid — 1.0x, faint targeting grid where combat lives.
# ---------------------------------------------------------------------------
class _GridLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var offset_y: float = 0.0
	const CELL := 48.0

	func setup(_vp: Vector2, t: Color, _rng: RandomNumberGenerator) -> void:
		tint = t

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func tick(delta: float, speed: float, _vp: Vector2) -> void:
		offset_y = fmod(offset_y + speed * delta, CELL)
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var line := Color(1.0, 1.0, 1.0, 0.045)
		var accent := Color(1.0, 1.0, 1.0, 0.08)
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
# Foreground — 1.5x, metal debris, embers, and smoke puffs over the action.
# ---------------------------------------------------------------------------
class _ForegroundLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var debris: Array[Dictionary] = []
	var embers: Array[Vector3] = [] # x, y, radius
	var puffs: Array[Vector3] = [] # x, y, width
	var _rng: RandomNumberGenerator
	var _time: float = 0.0

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		debris.clear()
		embers.clear()
		puffs.clear()
		for i in 10:
			_spawn_debris(vp, rng.randf() * vp.y)
		for i in 14:
			embers.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(1.0, 2.6)))
		for i in 3:
			puffs.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(60.0, 120.0)))

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func _spawn_debris(vp: Vector2, y: float) -> void:
		debris.append({
			"pos": Vector2(_rng.randf() * vp.x, y),
			"size": _rng.randf_range(5.0, 15.0),
			"rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-2.5, 2.5),
			"pts": _make_shard(_rng.randf_range(5.0, 15.0)),
		})

	func _make_shard(r: float) -> PackedVector2Array:
		## Angular industrial plate, not a rounded rock.
		var pts := PackedVector2Array()
		var n := 6 + _rng.randi() % 3
		for i in n:
			var a := TAU * float(i) / float(n) + _rng.randf_range(-0.2, 0.2)
			var rr := r * _rng.randf_range(0.5, 1.0)
			pts.append(Vector2(cos(a), sin(a)) * rr)
		return pts

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_time += delta
		for i in debris.size():
			var d: Dictionary = debris[i]
			var pos: Vector2 = d["pos"]
			pos.y += speed * delta
			d["rot"] = float(d["rot"]) + float(d["spin"]) * delta
			if pos.y > vp.y + 30.0:
				pos.y = -20.0 - _rng.randf_range(0.0, 120.0)
				pos.x = _rng.randf() * vp.x
				d["pts"] = _make_shard(_rng.randf_range(5.0, 15.0))
				d["size"] = _rng.randf_range(5.0, 15.0)
			d["pos"] = pos
			debris[i] = d
		for i in embers.size():
			var e := embers[i]
			e.y += speed * delta * 0.9
			e.x += sin(_time * 1.7 + float(i) * 2.4) * 6.0 * delta
			if e.y > vp.y + 10.0:
				e.y = -6.0
				e.x = _rng.randf() * vp.x
			embers[i] = e
		for i in puffs.size():
			var p := puffs[i]
			p.y += speed * delta * 0.7
			if p.y > vp.y + 60.0:
				p.y = -60.0
				p.x = _rng.randf() * vp.x
			puffs[i] = p
		queue_redraw()

	func _draw() -> void:
		for p in puffs:
			draw_circle(Vector2(p.x, p.y), p.z * 0.5, Color(0.07, 0.07, 0.09, 0.35))
			draw_circle(Vector2(p.x + p.z * 0.3, p.y + 8.0), p.z * 0.38, Color(0.05, 0.05, 0.07, 0.3))
		for e in embers:
			var tw := 0.5 + 0.5 * sin(_time * 6.0 + float(e.z) * 9.0)
			var a := 0.35 + 0.55 * tw
			draw_circle(Vector2(e.x, e.y), e.z, Color(1.0, 0.55, 0.25, a))
		for d in debris:
			var pos: Vector2 = d["pos"]
			var rot: float = d["rot"]
			var pts: PackedVector2Array = d["pts"]
			var xform := Transform2D(rot, pos)
			var world := PackedVector2Array()
			for p in pts:
				world.append(xform * p)
			draw_colored_polygon(world, Color(0.5, 0.48, 0.46, 0.6))
			if world.size() >= 2:
				draw_polyline(world + PackedVector2Array([world[0]]), Color(0.85, 0.8, 0.75, 0.4), 1.0)
			draw_circle(pos, 1.2, Color(1.0, 0.7, 0.35, 0.5))
