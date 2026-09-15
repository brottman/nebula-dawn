extends Node2D
## Enemy-base flyover. The camera rides above a fortified military
## installation looking down, so the whole playfield is the base itself:
##   Haze        static — altitude gradient + distance glow
##   GroundBase  1.00x — terrain, road grid, lots, buildings, hangars,
##                       tanks, turrets, props and moving ground vehicles
##   CloudDeck   1.22x — soft cloud layer (with shadows) slipping overhead
##   Foreground  1.50x — smoke, embers and debris close to the camera
## Every layer is drawn procedurally (no sprite assets) and scrolls forever.

const SPEED_CLOUD := 1.22
const SPEED_FG := 1.5

@export var scroll_speed: float = 40.0
@export var tint: Color = Color(0.12, 0.16, 0.38)

var _haze: _HazeLayer
var _ground: _GroundBase
var _clouds: _CloudLayer
var _fg: _ForegroundLayer
var _rng := RandomNumberGenerator.new()
var _style: StringName = &"city"


func _ready() -> void:
	_rng.randomize()

	_haze = _HazeLayer.new()
	_haze.name = "Haze"
	_haze.z_index = -40
	add_child(_haze)

	_ground = _GroundBase.new()
	_ground.name = "GroundBase"
	_ground.z_index = -20
	add_child(_ground)

	_clouds = _CloudLayer.new()
	_clouds.name = "CloudDeck"
	_clouds.z_index = -10
	add_child(_clouds)

	_fg = _ForegroundLayer.new()
	_fg.name = "Foreground"
	_fg.z_as_relative = false
	_fg.z_index = 50
	add_child(_fg)

	var vp := get_viewport_rect().size
	_haze.setup(vp, tint, _rng)
	_ground.setup(vp, tint, _rng)
	_clouds.setup(vp, tint, _rng)
	_fg.setup(vp, tint, _rng)
	get_viewport().size_changed.connect(_on_viewport_resized)
	set_style(_style)


func _on_viewport_resized() -> void:
	var vp := get_viewport_rect().size
	_haze.on_resize(vp)
	_ground.on_resize(vp)
	_clouds.on_resize(vp)
	_fg.on_resize(vp)


func set_style(s: StringName) -> void:
	_style = s
	if _haze:
		_haze.set_style_name(s)
	if _ground:
		_ground.set_style(s)
	if _clouds:
		_clouds.set_style(s)


func set_terrain(style: StringName) -> void:
	set_style(style)


func set_terrain_random() -> void:
	set_style(_GroundBase.STYLE_KEYS[_rng.randi() % _GroundBase.STYLE_KEYS.size()])


func set_tint(c: Color) -> void:
	tint = c
	for layer in [_haze, _ground, _clouds, _fg]:
		if layer:
			layer.set("tint", c)
			layer.queue_redraw()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	_haze.tick(delta, scroll_speed * 0.05, vp)
	_ground.tick(delta, scroll_speed, vp)
	_clouds.tick(delta, scroll_speed * SPEED_CLOUD, vp)
	_fg.tick(delta, scroll_speed * SPEED_FG, vp)


# ===========================================================================
# Haze — static altitude gradient with a lit distance band and soft vignette.
# ===========================================================================
class _HazeLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var _style: StringName = &"city"

	func setup(_vp: Vector2, t: Color, _rng: RandomNumberGenerator) -> void:
		tint = t

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_style_name(s: StringName) -> void:
		_style = s
		queue_redraw()

	func tick(_delta: float, _speed: float, _vp: Vector2) -> void:
		pass

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var pal: Dictionary = _GroundBase.palette_for(_style, tint)
		var ground: Color = pal["ground"]
		var far: Color = ground.lightened(0.30).lerp(pal["accent"], 0.10)
		# Distance haze at the top, clearing as it approaches the camera.
		var bands := 16
		for i in bands:
			var t := float(i) / float(bands - 1)
			var a := lerpf(0.42, 0.0, t * t)
			draw_rect(Rect2(0.0, vp.y * float(i) / float(bands), vp.x, vp.y / float(bands) + 1.0),
				Color(far.r, far.g, far.b, a))
		# Faint ground glow along the very top edge (lit by the horizon).
		draw_rect(Rect2(0.0, 0.0, vp.x, vp.y * 0.10), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.03))
		# Vignette so combat in the middle stays readable.
		for i in 4:
			var a := 0.05 + float(i) * 0.03
			var m := float(i) * 10.0
			draw_rect(Rect2(0, 0, vp.x, 3.0 + m), Color(0, 0, 0, a))
			draw_rect(Rect2(0, vp.y - 3.0 - m, vp.x, 3.0 + m), Color(0, 0, 0, a))


# ===========================================================================
# Ground base — the main event. A top-down military installation.
# ===========================================================================
class _GroundBase extends Node2D:
	const BLOCK_H := 320.0
	const ROAD_W := 46.0
	const CROSS_W := 34.0
	const ROWS := 2
	const LANES: Array[float] = [0.16, 0.5, 0.84]

	const STYLE_KEYS: Array[StringName] = [
		&"city", &"mines", &"biolum", &"factory", &"fleet",
		&"mirror", &"storm", &"wake", &"scrap", &"flare",
	]

	## Ground/structure flavour per style so the ten sectors read as different
	## places, not just different tints.
	const LAYOUTS := {
		&"city": &"grid",
		&"mines": &"quarry",
		&"biolum": &"grove",
		&"factory": &"industrial",
		&"fleet": &"airbase",
		&"mirror": &"plaza",
		&"storm": &"grid",
		&"wake": &"ruins",
		&"scrap": &"junkyard",
		&"flare": &"industrial",
	}

	const STYLES := {
		&"city": {
			"kinds": [&"block", &"warehouse", &"hangar", &"control", &"pad", &"tanks", &"turret"],
			"ground": Color(0.198, 0.190, 0.184), "road": Color(0.105, 0.107, 0.115),
			"roof": Color(0.300, 0.302, 0.320), "accent": Color(1.0, 0.66, 0.30),
			"detail": &"runway",
		},
		&"mines": {
			"kinds": [&"warehouse", &"tanks", &"refinery", &"crater", &"turret", &"block", &"crane", &"junk"],
			"ground": Color(0.220, 0.186, 0.150), "road": Color(0.130, 0.108, 0.090),
			"roof": Color(0.300, 0.250, 0.200), "accent": Color(1.0, 0.75, 0.35),
			"detail": &"road",
		},
		&"biolum": {
			"kinds": [&"dome", &"crystal", &"pad", &"control", &"comm", &"tanks", &"hangar"],
			"ground": Color(0.110, 0.165, 0.150), "road": Color(0.060, 0.100, 0.095),
			"roof": Color(0.150, 0.230, 0.210), "accent": Color(0.55, 1.0, 0.75),
			"detail": &"glow",
		},
		&"factory": {
			"kinds": [&"warehouse", &"refinery", &"hangar", &"tanks", &"crane", &"control", &"turret", &"block"],
			"ground": Color(0.165, 0.180, 0.192), "road": Color(0.090, 0.100, 0.110),
			"roof": Color(0.250, 0.285, 0.305), "accent": Color(0.45, 0.9, 1.0),
			"detail": &"road",
		},
		&"fleet": {
			"kinds": [&"hangar", &"pad", &"control", &"radar", &"turret", &"warehouse", &"comm"],
			"ground": Color(0.130, 0.155, 0.205), "road": Color(0.075, 0.090, 0.120),
			"roof": Color(0.210, 0.245, 0.310), "accent": Color(0.40, 0.70, 1.0),
			"detail": &"runway",
		},
		&"mirror": {
			"kinds": [&"crystal", &"dome", &"control", &"comm", &"radar", &"turret", &"pad"],
			"ground": Color(0.120, 0.170, 0.205), "road": Color(0.070, 0.105, 0.130),
			"roof": Color(0.190, 0.265, 0.315), "accent": Color(0.55, 0.9, 1.0),
			"detail": &"glow",
		},
		&"storm": {
			"kinds": [&"turret", &"tanks", &"comm", &"radar", &"block", &"control", &"warehouse"],
			"ground": Color(0.110, 0.145, 0.200), "road": Color(0.065, 0.085, 0.120),
			"roof": Color(0.165, 0.205, 0.270), "accent": Color(0.55, 0.8, 1.0),
			"detail": &"road",
		},
		&"wake": {
			"kinds": [&"junk", &"crater", &"block", &"radar", &"control", &"dome", &"turret"],
			"ground": Color(0.150, 0.130, 0.190), "road": Color(0.085, 0.075, 0.115),
			"roof": Color(0.210, 0.185, 0.265), "accent": Color(0.70, 0.55, 1.0),
			"detail": &"none",
		},
		&"scrap": {
			"kinds": [&"junk", &"hangar", &"crane", &"warehouse", &"turret", &"block", &"refinery"],
			"ground": Color(0.205, 0.165, 0.125), "road": Color(0.120, 0.095, 0.075),
			"roof": Color(0.285, 0.225, 0.170), "accent": Color(1.0, 0.6, 0.3),
			"detail": &"road",
		},
		&"flare": {
			"kinds": [&"refinery", &"control", &"tanks", &"turret", &"hangar", &"pad", &"block", &"comm"],
			"ground": Color(0.205, 0.150, 0.105), "road": Color(0.125, 0.085, 0.060),
			"roof": Color(0.290, 0.215, 0.150), "accent": Color(1.0, 0.85, 0.4),
			"detail": &"runway",
		},
	}

	var tint: Color = Color(0.12, 0.16, 0.38)
	var style: StringName = &"city"
	var scroll: float = 0.0
	var _time: float = 0.0
	var _rng: RandomNumberGenerator
	var _vehicles: Array[Dictionary] = []

	static func palette_for(s: StringName, t: Color) -> Dictionary:
		var p: Dictionary = STYLES.get(s, STYLES[&"city"])
		var ground: Color = Color(p["ground"]).lerp(t.darkened(0.40), 0.16).lightened(0.05)
		var road: Color = Color(p["road"]).lerp(t.darkened(0.55), 0.12)
		var roof: Color = Color(p["roof"]).lerp(t.darkened(0.02), 0.12).lightened(0.10)
		var accent: Color = Color(p["accent"]).lerp(t.lightened(0.25), 0.10)
		return {
			"ground": ground, "road": road, "roof": roof,
			"wall": roof.darkened(0.58), "accent": accent,
			"detail": p.get("detail", &"none"), "kinds": p.get("kinds", [&"block"]),
			"layout": LAYOUTS.get(s, &"grid"),
		}

	func setup(_vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		_vehicles.clear()
		for i in 9:
			var lane: int = i % LANES.size()
			_vehicles.append({
				"x": LANES[lane], "sy": rng.randf() * 720.0,
				"rel": rng.randf_range(-80.0, 100.0), "dir": 1.0 if lane != 1 else -1.0,
				"kind": ["tank", "apc", "truck", "jeep"][rng.randi() % 4],
				"seed": rng.randi(), "lane": lane, "w": rng.randf_range(24.0, 34.0),
			})

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_style(s: StringName) -> void:
		style = s
		scroll = 0.0
		queue_redraw()

	func _palette() -> Dictionary:
		return palette_for(style, tint)

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		scroll += speed * delta
		_time += delta
		for i in _vehicles.size():
			var v: Dictionary = _vehicles[i]
			v["sy"] = float(v["sy"]) + (speed + float(v["rel"])) * delta
			var sy := float(v["sy"])
			if sy > vp.y + 70.0:
				v["sy"] = -70.0
				v["seed"] = _rng.randi()
			elif sy < -70.0:
				v["sy"] = vp.y + 70.0
				v["seed"] = _rng.randi()
			_vehicles[i] = v
		queue_redraw()

	func _h(seed: int, i: int) -> float:
		var v := sin(float(seed) * 12.9898 + float(i) * 78.233) * 43758.5453
		return v - floor(v)

	func _lerp_h(seed: int, i: int, a: float, b: float) -> float:
		return lerpf(a, b, _h(seed, i))

	# --- top level ----------------------------------------------------------
	func _draw() -> void:
		var vp := get_viewport_rect().size
		if vp.x <= 0.0 or vp.y <= 0.0:
			return
		var pal := _palette()
		_draw_ground(vp, pal)
		_draw_vertical_roads(vp, pal)
		var first := int(floor((scroll - vp.y) / BLOCK_H)) - 1
		var last := int(floor(scroll / BLOCK_H)) + 1
		for idx in range(first, last + 1):
			_draw_block(idx, vp, pal)
		_draw_vehicles(vp, pal)

	func _draw_ground(vp: Vector2, pal: Dictionary) -> void:
		draw_rect(Rect2(0, 0, vp.x, vp.y), pal["ground"])
		# Mottled earth / concrete patches, deterministic in world space.
		var cell := 96.0
		var band := int(floor(scroll / cell))
		for r in range(-1, int(vp.y / cell) + 2):
			for c in range(0, int(vp.x / cell) + 1):
				var idx := band + r
				var h := _h(idx * 131 + c, 7)
				var x := float(c) * cell
				var y := float(idx) * cell - scroll
				if h > 0.55:
					var s := cell * _lerp_h(idx * 131 + c, 1, 0.5, 1.05)
					var col: Color = pal["ground"].lightened(0.06) if h < 0.8 else pal["ground"].darkened(0.14)
					draw_rect(Rect2(x + cell * 0.2, y + cell * 0.2, s, s), Color(col.r, col.g, col.b, 0.35))
				# oil / scorch stains
				var hs := _h(idx * 211 + c, 13)
				if hs > 0.80:
					var rr := cell * _lerp_h(idx * 211 + c, 14, 0.10, 0.24)
					draw_circle(Vector2(x + cell * 0.5, y + cell * 0.5), rr, Color(0, 0, 0, 0.17))
					draw_circle(Vector2(x + cell * 0.5 + rr * 0.3, y + cell * 0.5 - rr * 0.2), rr * 0.6, Color(0, 0, 0, 0.12))
				# hairline cracks
				if _h(idx * 307 + c, 17) > 0.86:
					var a := _h(idx * 307 + c, 18) * TAU
					draw_line(Vector2(x + 8.0, y + 8.0),
						Vector2(x + 8.0, y + 8.0) + Vector2(cos(a), sin(a)) * cell * 0.7,
						Color(0, 0, 0, 0.18), 1.0)

	func _draw_vertical_roads(vp: Vector2, pal: Dictionary) -> void:
		for lane in LANES:
			var cx := vp.x * lane
			var x0 := cx - ROAD_W * 0.5
			# shoulder / curb
			draw_rect(Rect2(x0 - 4.0, 0, ROAD_W + 8.0, vp.y), pal["ground"].darkened(0.22))
			draw_rect(Rect2(x0, 0, ROAD_W, vp.y), pal["road"])
			# lane edge lines
			draw_rect(Rect2(x0 + 3.0, 0, 1.5, vp.y), Color(1, 1, 1, 0.06))
			draw_rect(Rect2(x0 + ROAD_W - 4.5, 0, 1.5, vp.y), Color(1, 1, 1, 0.06))
			# dashes
			var dash := 62.0
			var off := fmod(scroll, dash)
			var y := -dash + off
			while y < vp.y + dash:
				draw_rect(Rect2(cx - 1.5, y, 3.0, 26.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.42))
				y += dash
			# street lamps
			var lamp := 150.0
			var loff := fmod(scroll, lamp)
			var ly := -lamp + loff
			while ly < vp.y + lamp:
				draw_circle(Vector2(x0 - 7.0, ly), 2.2, Color(1.0, 0.9, 0.6, 0.85))
				draw_circle(Vector2(x0 - 7.0, ly), 16.0, Color(1.0, 0.85, 0.5, 0.05))
				draw_circle(Vector2(x0 + ROAD_W + 7.0, ly + lamp * 0.5), 2.2, Color(1.0, 0.9, 0.6, 0.85))
				draw_circle(Vector2(x0 + ROAD_W + 7.0, ly + lamp * 0.5), 16.0, Color(1.0, 0.85, 0.5, 0.05))
				ly += lamp
			# detail flavour
			var detail: StringName = pal.get("detail", &"none")
			if detail == &"runway":
				var coff := fmod(scroll, 26.0)
				var cy := -26.0 + coff
				while cy < vp.y + 26.0:
					draw_rect(Rect2(cx - 1.0, cy, 2.0, 12.0), Color(1, 1, 1, 0.10))
					cy += 26.0

	func _draw_block(idx: int, vp: Vector2, pal: Dictionary) -> void:
		var by := scroll - float(idx) * BLOCK_H
		if by > vp.y + BLOCK_H or by + BLOCK_H < -40.0:
			return
		var seed := idx * 7919
		_draw_cross_road(by, vp, pal)
		_draw_style_decor(seed, by, vp, pal)
		var avail := BLOCK_H - CROSS_W
		var lot_ax := vp.x * (LANES[0] + LANES[1]) * 0.5
		var lot_bx := vp.x * (LANES[1] + LANES[2]) * 0.5
		# Some blocks give a whole lot over to an airfield runway.
		var runway_col := -1
		if String(pal.get("detail", &"none")) == "runway" and _h(seed, 77) > 0.5:
			runway_col = 0 if _h(seed, 78) < 0.5 else 1
		if runway_col >= 0:
			_draw_runway(seed, lot_ax if runway_col == 0 else lot_bx, by, avail, vp, pal)
		for row in ROWS:
			var cy := by + CROSS_W + avail * (float(row) + 0.5) / float(ROWS)
			for col in 2:
				if col == runway_col:
					continue
				var cid := row * 2 + col
				if _h(seed, cid * 11 + 3) < 0.16:
					continue
				_draw_cell(seed, cid, lot_ax if col == 0 else lot_bx, cy, avail / float(ROWS), vp, pal)
		_draw_edges(seed, by, vp, pal)

	func _draw_runway(seed: int, cx: float, by: float, avail: float, vp: Vector2, pal: Dictionary) -> void:
		var w := vp.x * (LANES[1] - LANES[0]) - ROAD_W - 10.0
		var y0 := by + CROSS_W + 8.0
		var h := avail - 16.0
		var road: Color = pal["road"].lightened(0.04)
		draw_rect(Rect2(cx - w * 0.5, y0, w, h), road)
		draw_rect(Rect2(cx - w * 0.5, y0, w, 2.0), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(cx - w * 0.5, y0 + h - 2.0, w, 2.0), Color(1, 1, 1, 0.06))
		# threshold piano keys top and bottom
		for side in 2:
			var ty := y0 + 10.0 if side == 0 else y0 + h - 26.0
			var bars := 6
			for i in bars:
				var bx := cx - w * 0.34 + w * 0.68 * float(i) / float(bars - 1)
				draw_rect(Rect2(bx - w * 0.03, ty, w * 0.06, 16.0), Color(1, 1, 1, 0.16))
		# centreline
		var dash := 44.0
		var off := fmod(scroll, dash)
		var y := y0 - dash + off
		while y < y0 + h + dash:
			if y > y0 + 30.0 and y < y0 + h - 30.0:
				draw_rect(Rect2(cx - 2.0, y, 4.0, 24.0), Color(1, 1, 1, 0.22))
			y += dash
		# edge lights
		var lstep := 60.0
		var loff := fmod(scroll, lstep)
		var ly := y0 - lstep + loff
		while ly < y0 + h + lstep:
			var blink := 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 3.0 + ly * 0.1))
			var a := 0.4 if GameState.reduce_flashes else blink
			draw_circle(Vector2(cx - w * 0.5 + 4.0, ly), 1.8, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, a))
			draw_circle(Vector2(cx + w * 0.5 - 4.0, ly), 1.8, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, a))
			ly += lstep
		# runway number
		draw_rect(Rect2(cx - w * 0.16, y0 + h * 0.42, w * 0.32, 20.0), Color(1, 1, 1, 0.10))

	func _draw_cross_road(by: float, vp: Vector2, pal: Dictionary) -> void:
		draw_rect(Rect2(0, by, vp.x, CROSS_W), pal["road"])
		draw_rect(Rect2(0, by, vp.x, 2.0), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(0, by + CROSS_W - 2.0, vp.x, 2.0), Color(1, 1, 1, 0.05))
		# centre dashes
		var dash := 54.0
		var x := fmod(scroll * 0.5, dash)
		while x < vp.x + dash:
			draw_rect(Rect2(x, by + CROSS_W * 0.5 - 1.5, 24.0, 3.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.32))
			x += dash
		# crosswalk zebra at each vertical road
		for lane in LANES:
			var cx := vp.x * lane
			for i in 4:
				var sx := cx - ROAD_W * 0.5 + 4.0 + float(i) * (ROAD_W - 8.0) / 4.0
				draw_rect(Rect2(sx, by + 4.0, (ROAD_W - 8.0) / 4.0 - 3.0, CROSS_W - 8.0), Color(1, 1, 1, 0.07))

	func _draw_cell(seed: int, cid: int, cx: float, cy: float, row_h: float, vp: Vector2, pal: Dictionary) -> void:
		var kinds: Array = pal["kinds"]
		var kind: StringName = kinds[int(_h(seed, cid * 11 + 1) * float(kinds.size())) % kinds.size()]
		var lot_w := vp.x * (LANES[1] - LANES[0]) - ROAD_W - 14.0
		var w := lot_w * _lerp_h(seed, cid * 11 + 5, 0.5, 0.94)
		var d := maxf(46.0, row_h * _lerp_h(seed, cid * 11 + 6, 0.42, 0.82))
		var x := cx + _lerp_h(seed, cid * 11 + 8, -10.0, 10.0)
		var y := cy + _lerp_h(seed, cid * 11 + 9, -8.0, 8.0)
		# concrete pad under every structure
		var pad: Color = pal["ground"].lightened(0.08)
		var phw := w * 0.68
		var phd := d * 0.68
		draw_rect(Rect2(x - phw, y - phd, phw * 2.0, phd * 2.0), pad)
		draw_rect(Rect2(x - phw, y - phd, phw * 2.0, phd * 2.0), Color(1, 1, 1, 0.02))
		# pad corner markings
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				draw_line(Vector2(x + sx * phw, y + sy * phd), Vector2(x + sx * (phw - 10.0), y + sy * phd), Color(1, 1, 1, 0.10), 1.5)
				draw_line(Vector2(x + sx * phw, y + sy * phd), Vector2(x + sx * phw, y + sy * (phd - 10.0)), Color(1, 1, 1, 0.10), 1.5)
		# per-building roof tint so lots don't read as one flat gray
		var rpal := pal.duplicate()
		rpal["roof"] = pal["roof"].lightened(_lerp_h(seed, cid * 11 + 20, -0.06, 0.14))
		rpal["wall"] = rpal["roof"].darkened(0.42)
		_paint(kind, x, y, w, d, seed + cid * 97, rpal)
		# yard density: containers, sheds, barrels, barriers, light poles
		for i in 7:
			if _h(seed, cid * 11 + 100 + i) < 0.30:
				continue
			var px := x + _lerp_h(seed, cid * 11 + 200 + i, -1.0, 1.0) * (phw - 8.0)
			var py := y + _lerp_h(seed, cid * 11 + 300 + i, -1.0, 1.0) * (phd - 8.0)
			# keep clutter out of the building footprint
			if absf(px - x) < w * 0.54 and absf(py - y) < d * 0.54:
				py = y + (d * 0.60 if py >= y else -d * 0.60)
			_draw_yard_prop(seed + cid * 13 + i, px, py, pal)
		# parked vehicle row along the near edge of the pad
		if _h(seed, cid * 11 + 400) > 0.45:
			var vy := y + phd - 7.0
			for i in 3:
				var vk: String = ["tank", "apc", "truck", "jeep"][int(_h(seed, cid * 11 + 410 + i) * 4.0) % 4]
				_draw_vehicle(vk, x - w * 0.30 + float(i) * 15.0, vy, 13.0, 1.0, seed + cid + i, pal)
		if _h(seed, cid * 11 + 10) > 0.6:
			_draw_parking(x - phw, y + phd + 5.0, phw * 2.0, 24.0, seed + cid)

	func _draw_yard_prop(seed: int, x: float, y: float, pal: Dictionary) -> void:
		var roof: Color = pal["roof"]
		var accent: Color = pal["accent"]
		match int(_h(seed, 1) * 6.0) % 6:
			0: # crate stack
				draw_rect(Rect2(x - 4.0, y - 4.0, 8.0, 8.0), roof.darkened(0.22))
				draw_rect(Rect2(x - 4.0, y - 4.0, 8.0, 2.0), roof.lightened(0.22))
			1: # barrel pair
				for i in 2:
					draw_circle(Vector2(x + float(i) * 5.0 - 2.5, y), 2.6, roof.darkened(0.16))
					draw_circle(Vector2(x + float(i) * 5.0 - 2.5, y - 0.6), 1.2, roof.lightened(0.18))
			2: # shipping container
				var col: Color = Color(0.55, 0.36, 0.26) if _h(seed, 2) > 0.5 else Color(0.28, 0.44, 0.55)
				col = col.lerp(accent, 0.12)
				draw_rect(Rect2(x - 9.0, y - 4.0, 18.0, 8.0), col.darkened(0.3))
				draw_rect(Rect2(x - 9.0, y - 4.0, 18.0, 3.0), col)
				for r in 3:
					draw_line(Vector2(x - 6.0 + float(r) * 6.0, y - 4.0), Vector2(x - 6.0 + float(r) * 6.0, y + 4.0), col.darkened(0.4), 0.8)
			3: # small shed
				draw_rect(Rect2(x - 7.0, y - 5.0, 14.0, 10.0), roof.darkened(0.12))
				draw_rect(Rect2(x - 7.0, y - 5.0, 14.0, 2.5), roof.lightened(0.26))
				draw_rect(Rect2(x - 7.0, y + 3.0, 14.0, 2.0), roof.darkened(0.5))
			4: # light pole
				draw_circle(Vector2(x, y), 9.0, Color(accent.r, accent.g, accent.b, 0.06))
				draw_circle(Vector2(x, y), 1.8, Color(1.0, 0.92, 0.65, 0.85))
			5: # sandbag / barrier
				draw_rect(Rect2(x - 7.0, y - 3.0, 14.0, 6.0), roof.darkened(0.34))
				draw_rect(Rect2(x - 7.0, y - 3.0, 14.0, 1.5), roof.lightened(0.12))

	func _draw_style_decor(seed: int, by: float, vp: Vector2, pal: Dictionary) -> void:
		## Ground-level flavour drawn under the lots so each style reads as a
		## different kind of installation, not just a different tint.
		var accent: Color = pal["accent"]
		var ground: Color = pal["ground"]
		match String(pal.get("layout", "grid")):
			"quarry":
				for i in 5:
					var cx := vp.x * _lerp_h(seed, i * 5 + 1, 0.06, 0.94)
					var cy := by + _lerp_h(seed, i * 5 + 2, 0.06, 0.94) * BLOCK_H
					var r := _lerp_h(seed, i * 5 + 3, 12.0, 30.0)
					draw_circle(Vector2(cx, cy), r, ground.darkened(0.28))
					draw_arc(Vector2(cx, cy), r, 0, TAU, 16, ground.lightened(0.12), 1.5)
				for i in 4:
					var ox := vp.x * _lerp_h(seed, i * 7 + 40, 0.08, 0.92)
					var oy := by + _lerp_h(seed, i * 7 + 41, 0.1, 0.9) * BLOCK_H
					var s := _lerp_h(seed, i * 7 + 42, 5.0, 11.0)
					draw_colored_polygon(PackedVector2Array([
						Vector2(ox - s, oy + s * 0.6), Vector2(ox + s, oy + s * 0.6), Vector2(ox, oy - s * 0.8),
					]), ground.lightened(0.10).lerp(accent, 0.12))
			"junkyard":
				for i in 7:
					var jx := vp.x * _lerp_h(seed, i * 6 + 1, 0.05, 0.95)
					var jy := by + _lerp_h(seed, i * 6 + 2, 0.05, 0.95) * BLOCK_H
					var s := _lerp_h(seed, i * 6 + 3, 8.0, 20.0)
					var pts := PackedVector2Array()
					var rot := _h(seed, i * 6 + 4) * TAU
					for k in 5:
						var a := rot + TAU * float(k) / 5.0
						pts.append(Vector2(jx + cos(a) * s, jy + sin(a) * s * 0.65))
					draw_colored_polygon(pts, ground.lightened(0.06).lerp(accent, 0.10))
					draw_polyline(pts + PackedVector2Array([pts[0]]), ground.darkened(0.3), 1.0)
			"ruins":
				for i in 6:
					var rx := vp.x * _lerp_h(seed, i * 6 + 1, 0.05, 0.95)
					var ry := by + _lerp_h(seed, i * 6 + 2, 0.05, 0.95) * BLOCK_H
					var rw := _lerp_h(seed, i * 6 + 3, 14.0, 40.0)
					var rh := _lerp_h(seed, i * 6 + 4, 8.0, 22.0)
					draw_rect(Rect2(rx, ry, rw, rh), ground.darkened(0.18))
					draw_rect(Rect2(rx, ry, rw, 2.0), ground.lightened(0.10))
					for k in 3:
						draw_circle(Vector2(rx + _h(seed, i * 9 + k) * rw, ry + rh + 3.0), 2.0, ground.darkened(0.3))
			"grove":
				for i in 6:
					var gx := vp.x * _lerp_h(seed, i * 6 + 1, 0.05, 0.95)
					var gy := by + _lerp_h(seed, i * 6 + 2, 0.05, 0.95) * BLOCK_H
					var gx2 := gx + _lerp_h(seed, i * 6 + 3, -60.0, 60.0)
					var gy2 := gy + _lerp_h(seed, i * 6 + 4, -50.0, 50.0)
					draw_line(Vector2(gx, gy), Vector2(gx2, gy2), Color(accent.r, accent.g, accent.b, 0.20), 2.0)
					draw_circle(Vector2(gx2, gy2), 2.5, Color(accent.r, accent.g, accent.b, 0.5))
			"plaza":
				var tile := 60.0
				var off := fmod(scroll, tile)
				var ty := -tile + off
				while ty < vp.y + tile:
					draw_line(Vector2(0, ty), Vector2(vp.x, ty), Color(1, 1, 1, 0.045), 1.0)
					ty += tile
				var tx := 0.0
				while tx < vp.x:
					draw_line(Vector2(tx, 0), Vector2(tx, vp.y), Color(1, 1, 1, 0.045), 1.0)
					tx += tile
			"industrial":
				for i in 3:
					var py := by + BLOCK_H * (0.2 + 0.3 * float(i))
					draw_line(Vector2(0, py), Vector2(vp.x, py), ground.darkened(0.25), 3.0)
					draw_line(Vector2(0, py - 1.5), Vector2(vp.x, py - 1.5), ground.lightened(0.10), 1.0)
					for k in 5:
						draw_circle(Vector2(vp.x * (float(k) + 0.5) / 5.0, py), 3.0, ground.lightened(0.12))
			"airbase":
				for i in 8:
					var ax := vp.x * (float(i) + 0.5) / 8.0
					draw_line(Vector2(ax, by), Vector2(ax, by + BLOCK_H), Color(1, 1, 1, 0.02))
			_:
				pass

	func _draw_edges(seed: int, by: float, vp: Vector2, pal: Dictionary) -> void:
		# Perimeter wall + fence posts down both screen edges.
		var wall := 7.0
		for side in [0.0, 1.0]:
			var x := wall * 0.5 if side == 0.0 else vp.x - wall * 0.5
			draw_rect(Rect2(x - wall * 0.5, by, wall, BLOCK_H), pal["roof"].darkened(0.25))
			var py := by
			while py < by + BLOCK_H:
				var fx := x + (8.0 if side == 0.0 else -12.0)
				draw_rect(Rect2(fx, py, 4.0, 2.0), pal["roof"].darkened(0.05))
				draw_line(Vector2(fx + 2.0, py + 1.0), Vector2(fx + 2.0, py + 18.0), pal["roof"].darkened(0.18), 0.8)
				py += 18.0
		# Watch towers on alternating blocks.
		if int(seed) % 3 == 0:
			_draw_watchtower(14.0, by + BLOCK_H * 0.5, seed, pal)
			_draw_watchtower(vp.x - 14.0, by + BLOCK_H * 0.28, seed + 1, pal)
		# Yard clutter in the narrow edge strips.
		for side in 2:
			var bx := 30.0 if side == 0 else vp.x - 46.0
			var hv := _h(seed, side * 5 + 1)
			if hv > 0.6:
				_paint(&"tanks", bx, by + BLOCK_H * 0.5, 26.0, 60.0, seed + side, pal)
			elif hv > 0.3:
				_paint(&"junk", bx, by + BLOCK_H * 0.5, 34.0, 44.0, seed + side + 9, pal)
			else:
				for i in 4:
					_draw_yard_prop(seed + side * 31 + i, bx + float(i % 2) * 11.0 - 5.0,
						by + BLOCK_H * 0.30 + float(i) * 17.0, pal)

	func _draw_vehicles(vp: Vector2, pal: Dictionary) -> void:
		for raw in _vehicles:
			var v: Dictionary = raw
			var x := vp.x * float(v["x"])
			if bool(v["dir"] > 0.0):
				x += ROAD_W * 0.22
			else:
				x -= ROAD_W * 0.22
			_draw_vehicle(String(v["kind"]), x, float(v["sy"]), float(v["w"]), float(v["dir"]), int(v["seed"]), pal)

	# --- vehicles -----------------------------------------------------------
	func _draw_vehicle(kind: String, x: float, y: float, w: float, dir: float, seed: int, pal: Dictionary) -> void:
		var body: Color = pal["roof"].darkened(0.16)
		var dark: Color = pal["roof"].darkened(0.45)
		var accent: Color = pal["accent"]
		match kind:
			"tank":
				var tr := w * 0.28
				draw_rect(Rect2(x - tr * 2.0, y - tr * 2.6, tr * 1.0, tr * 5.2), dark)
				draw_rect(Rect2(x + tr * 1.0, y - tr * 2.6, tr * 1.0, tr * 5.2), dark)
				draw_rect(Rect2(x - tr * 1.3, y - tr * 2.1, tr * 2.6, tr * 4.2), body)
				draw_circle(Vector2(x, y), tr * 0.95, body.lightened(0.08))
				draw_circle(Vector2(x, y), tr * 0.6, dark)
				draw_line(Vector2(x, y), Vector2(x, y + dir * w * 1.15), dark.lightened(0.12), w * 0.10)
			"apc":
				draw_rect(Rect2(x - w * 0.42, y - w * 0.62, w * 0.84, w * 1.24), body)
				draw_rect(Rect2(x - w * 0.30, y - w * 0.42, w * 0.6, w * 0.5), dark)
				draw_circle(Vector2(x - w * 0.34, y - w * 0.3), w * 0.12, dark)
				draw_circle(Vector2(x + w * 0.34, y - w * 0.3), w * 0.12, dark)
				draw_circle(Vector2(x - w * 0.34, y + w * 0.3), w * 0.12, dark)
				draw_circle(Vector2(x + w * 0.34, y + w * 0.3), w * 0.12, dark)
				_vehicle_lights(x, y, w, dir, accent)
			"truck":
				draw_rect(Rect2(x - w * 0.34, y - w * 0.6, w * 0.68, w * 0.42), body)
				draw_rect(Rect2(x - w * 0.30, y - w * 0.14, w * 0.6, w * 0.7), body.darkened(0.12))
				draw_circle(Vector2(x - w * 0.3, y + w * 0.5), w * 0.12, dark)
				draw_circle(Vector2(x + w * 0.3, y + w * 0.5), w * 0.12, dark)
				_vehicle_lights(x, y, w, dir, accent)
			_:
				draw_rect(Rect2(x - w * 0.32, y - w * 0.5, w * 0.64, w), body)
				draw_rect(Rect2(x - w * 0.22, y - w * 0.3, w * 0.44, w * 0.36), dark)
				draw_circle(Vector2(x - w * 0.3, y - w * 0.28), w * 0.1, dark)
				draw_circle(Vector2(x + w * 0.3, y - w * 0.28), w * 0.1, dark)
				_vehicle_lights(x, y, w, dir, accent)
		draw_circle(Vector2(x, y - dir * w * 0.9), 1.4, Color(1.0, 0.55, 0.3, 0.85))

	func _vehicle_lights(x: float, y: float, w: float, dir: float, accent: Color) -> void:
		var hy := y - dir * w * 0.62
		draw_circle(Vector2(x - w * 0.3, hy), 1.5, Color(1.0, 0.95, 0.7, 0.9))
		draw_circle(Vector2(x + w * 0.3, hy), 1.5, Color(1.0, 0.95, 0.7, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.45, hy), Vector2(x + w * 0.45, hy),
			Vector2(x + w * 0.8, hy - dir * w * 2.2), Vector2(x - w * 0.8, hy - dir * w * 2.2),
		]), Color(accent.r, accent.g, accent.b, 0.06))

	func _draw_parking(x: float, y: float, w: float, h: float, seed: int) -> void:
		draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.18))
		var stalls := 5
		for i in stalls:
			var sx := x + w * float(i) / float(stalls)
			draw_line(Vector2(sx, y), Vector2(sx, y + h), Color(1, 1, 1, 0.10), 1.0)
			if _h(seed, i * 3 + 1) > 0.5:
				var cx := sx + w / float(stalls) * 0.5
				var col := Color(0.55, 0.58, 0.62, 0.9) if _h(seed, i * 3 + 2) > 0.5 else Color(0.45, 0.30, 0.25, 0.9)
				draw_rect(Rect2(cx - w * 0.055, y + h * 0.18, w * 0.11, h * 0.5), col)

	func _draw_watchtower(x: float, y: float, seed: int, pal: Dictionary) -> void:
		draw_rect(Rect2(x - 8.0, y - 8.0, 16.0, 16.0), pal["roof"].darkened(0.3))
		draw_rect(Rect2(x - 5.0, y - 5.0, 10.0, 10.0), pal["roof"])
		draw_line(Vector2(x, y - 5.0), Vector2(x, y - 16.0), pal["roof"].darkened(0.2), 1.5)
		var blink := 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 3.2 + float(seed)))
		draw_circle(Vector2(x, y - 16.0), 1.8, Color(1.0, 0.3, 0.25, blink if not GameState.reduce_flashes else 0.5))

	# ======================================================================
	# Top-down structure painters.
	# ======================================================================
	func _paint(kind: StringName, x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var roof: Color = pal["roof"]
		match kind:
			&"hangar": _paint_hangar(x, y, w, d * 1.15, seed, pal)
			&"warehouse": _paint_warehouse(x, y, w, d, seed, pal)
			&"block": _paint_block(x, y, w * 0.85, d * 0.85, seed, roof, pal)
			&"control": _paint_control(x, y, w, d, seed, pal)
			&"radar": _paint_radar(x, y, w, d, seed, pal)
			&"tanks": _paint_tanks(x, y, w, d, seed, pal)
			&"refinery": _paint_refinery(x, y, w, d, seed, pal)
			&"turret": _paint_turret(x, y, w, d, seed, pal)
			&"pad": _paint_pad(x, y, w, d, seed, pal)
			&"comm": _paint_comm(x, y, w, d, seed, pal)
			&"crane": _paint_crane(x, y, w, d, seed, pal)
			&"junk": _paint_junk(x, y, w, d, seed, pal)
			&"crater": _paint_crater(x, y, w, d, seed, pal)
			&"dome": _paint_dome(x, y, w, d, seed, pal)
			&"crystal": _paint_crystal(x, y, w, d, seed, pal)
			_: _paint_block(x, y, w, d, seed, roof, pal)

	func _footprint(x: float, y: float, w: float, d: float, roof: Color, pal: Dictionary, tall: float = 7.0) -> void:
		## Shared shadow + near/side wall + roof slab for every building.
		var wall: Color = pal["wall"]
		draw_rect(Rect2(x - w * 0.5 + 5.0, y - d * 0.5 + 5.0, w, d + tall), Color(0, 0, 0, 0.40))
		draw_rect(Rect2(x - w * 0.5, y + d * 0.5, w, tall), wall)
		draw_rect(Rect2(x + w * 0.5, y - d * 0.5, tall * 0.55, d), wall.darkened(0.28))
		draw_rect(Rect2(x - w * 0.5, y - d * 0.5, w, d), roof)
		# crisp lit top/left edges and shaded bottom/right edges for depth
		draw_rect(Rect2(x - w * 0.5, y - d * 0.5, w, 2.5), roof.lightened(0.30))
		draw_rect(Rect2(x - w * 0.5, y - d * 0.5, 2.5, d), roof.lightened(0.18))
		draw_rect(Rect2(x - w * 0.5, y + d * 0.5 - 2.5, w, 2.5), roof.darkened(0.34))
		draw_rect(Rect2(x + w * 0.5 - 2.5, y - d * 0.5, 2.5, d), roof.darkened(0.22))
		# inner panel seam
		if w > 44.0 and d > 30.0:
			var inset := 4.0
			draw_rect(Rect2(x - w * 0.5 + inset, y - d * 0.5 + inset, w - inset * 2.0, 1.0), roof.lightened(0.10))
			draw_rect(Rect2(x - w * 0.5 + inset, y + d * 0.5 - inset - 1.0, w - inset * 2.0, 1.0), roof.darkened(0.18))

	func _roof_detail(seed: int, x: float, y: float, w: float, d: float, pal: Dictionary, dens: float = 1.0) -> void:
		## AC units, vents, skylights, hatches and painted markings.
		var accent: Color = pal["accent"]
		# roof panel seams for larger slabs
		if w > 70.0 and _h(seed, 66) > 0.4:
			var cols := 2 + int(_h(seed, 67) * 2.0)
			for i in cols:
				var lx := x - w * 0.42 + w * 0.84 * (float(i) + 1.0) / float(cols + 1)
				draw_rect(Rect2(lx, y - d * 0.46, 1.0, d * 0.92), pal["roof"].darkened(0.14))
		var count := int(4.0 * dens + _h(seed, 1) * 5.0)
		for i in count:
			var ux := x + _lerp_h(seed, i * 5 + 2, -w * 0.36, w * 0.36)
			var uy := y + _lerp_h(seed, i * 5 + 3, -d * 0.34, d * 0.34)
			var s := _lerp_h(seed, i * 5 + 4, 3.0, 7.5)
			draw_rect(Rect2(ux - s * 0.5 + 2.0, uy - s * 0.5 + 2.0, s, s), Color(0, 0, 0, 0.30))
			draw_rect(Rect2(ux - s * 0.5, uy - s * 0.5, s, s), pal["roof"].darkened(0.34))
			draw_rect(Rect2(ux - s * 0.5, uy - s * 0.5, s, s * 0.38), pal["roof"].lightened(0.24))
			if _h(seed, i * 5 + 5) > 0.65:
				draw_circle(Vector2(ux, uy), s * 0.30, Color(accent.r, accent.g, accent.b, 0.65))
		# skylight strip
		if w > 60.0 and _h(seed, 31) > 0.4:
			var sw := w * 0.5
			draw_rect(Rect2(x - sw * 0.5, y - d * 0.42, sw, d * 0.12), pal["roof"].lightened(0.32))
			draw_rect(Rect2(x - sw * 0.5, y - d * 0.42, sw, d * 0.12), Color(accent.r, accent.g, accent.b, 0.16))
		# lit perimeter trim on some roofs (night airbase feel, restrained)
		if _h(seed, 77) > 0.4:
			var trim := Color(accent.r, accent.g, accent.b, 0.32)
			draw_rect(Rect2(x - w * 0.5, y - d * 0.5, w, 1.5), trim)
			draw_rect(Rect2(x - w * 0.5, y - d * 0.5, 1.5, d), trim)
		# painted roof code / hazard square
		if _h(seed, 88) > 0.6:
			draw_rect(Rect2(x + w * 0.26, y + d * 0.26, 9.0, 9.0), Color(accent.r, accent.g, accent.b, 0.40))
			draw_rect(Rect2(x + w * 0.28, y + d * 0.28, 5.0, 5.0), pal["roof"].darkened(0.34))

	func _paint_block(x: float, y: float, w: float, d: float, seed: int, roof: Color, pal: Dictionary) -> void:
		_footprint(x, y, w, d, roof, pal, 8.0)
		_roof_detail(seed, x, y, w, d, pal)
		# roof access + painted hazard square
		draw_rect(Rect2(x + w * 0.28, y + d * 0.28, 8.0, 8.0), roof.darkened(0.35))
		if _h(seed, 41) > 0.6:
			draw_rect(Rect2(x - w * 0.42, y - d * 0.42, w * 0.2, 4.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.5))

	func _paint_warehouse(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var roof: Color = pal["roof"].darkened(0.06)
		_footprint(x, y, w, d, roof, pal, 9.0)
		# longitudinal skylight rows
		for r in 2:
			var ry := y - d * 0.18 + float(r) * d * 0.36
			draw_rect(Rect2(x - w * 0.40, ry - 2.5, w * 0.8, 5.0), roof.lightened(0.20))
			draw_rect(Rect2(x - w * 0.40, ry - 2.5, w * 0.8, 5.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.06))
		# loading dock notches + parked trucks
		for i in 3:
			var dy := y - d * 0.34 + float(i) * d * 0.34
			draw_rect(Rect2(x - w * 0.5 - 7.0, dy - 5.0, 7.0, 10.0), pal["wall"].darkened(0.1))
			if _h(seed, i * 4 + 1) > 0.4:
				draw_rect(Rect2(x - w * 0.5 - 20.0, dy - 5.0, 12.0, 10.0), pal["roof"].lightened(0.05))
		_roof_detail(seed + 3, x, y, w, d, pal, 0.7)

	func _paint_hangar(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var roof: Color = pal["roof"].lightened(0.04)
		var tall := 11.0
		_footprint(x, y, w, d, roof, pal, tall)
		# arched roof ribs along the long axis
		var ribs := 5
		for i in ribs:
			var rx := x - w * 0.42 + w * 0.84 * float(i) / float(ribs - 1)
			draw_line(Vector2(rx, y - d * 0.44), Vector2(rx, y + d * 0.44), roof.darkened(0.18), 1.3)
		# big open door on the near (bottom) face
		var dw := w * 0.72
		var door_y := y + d * 0.5
		draw_rect(Rect2(x - dw * 0.5, door_y, dw, tall + 4.0), pal["wall"].darkened(0.25))
		draw_rect(Rect2(x - dw * 0.5 + 2.0, door_y + 1.0, dw - 4.0, tall + 2.0), Color(0.02, 0.02, 0.02, 0.85))
		# interior glow + a parked craft
		draw_rect(Rect2(x - dw * 0.5 + 2.0, door_y + 1.0, dw - 4.0, tall + 2.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.16))
		draw_rect(Rect2(x - w * 0.14, door_y - 6.0, w * 0.28, 14.0), pal["roof"].darkened(0.2))
		draw_rect(Rect2(x - w * 0.05, door_y - 12.0, w * 0.10, 12.0), pal["roof"].darkened(0.35))
		# hazard chevrons by the door
		draw_rect(Rect2(x - w * 0.5, door_y - 5.0, w, 3.0), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.55))
		draw_circle(Vector2(x, y + d * 0.5 + tall * 0.5), 2.2, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.9))
		_roof_detail(seed + 7, x, y - d * 0.12, w * 0.8, d * 0.5, pal, 0.5)

	func _paint_control(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var bw := w * 0.62
		var bd := d * 0.62
		_footprint(x, y, bw, bd, pal["roof"].darkened(0.12), pal, 10.0)
		# upper cab + railing
		var cw := bw * 0.7
		var cd := bd * 0.7
		draw_rect(Rect2(x - cw * 0.5 + 3.0, y - cd * 0.5 + 3.0, cw, cd + 8.0), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(x - cw * 0.5, y - cd * 0.5, cw, cd), pal["roof"].lightened(0.10))
		draw_rect(Rect2(x - cw * 0.5, y - cd * 0.5, cw, 2.0), pal["roof"].lightened(0.22))
		# glass band with lit windows
		draw_rect(Rect2(x - cw * 0.44, y - cd * 0.44, cw * 0.88, cd * 0.22), Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.45))
		# antenna + beacon
		draw_line(Vector2(x, y - cd * 0.5), Vector2(x, y - cd * 0.5 - 14.0), pal["roof"].darkened(0.3), 1.6)
		var blink := 0.5 + 0.5 * sin(_time * 3.5 + float(seed))
		draw_circle(Vector2(x, y - cd * 0.5 - 14.0), 2.0, Color(1.0, 0.3, 0.25, 0.5 if GameState.reduce_flashes else blink))

	func _paint_radar(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var bw := w * 0.7
		var bd := d * 0.7
		_footprint(x, y, bw, bd * 0.8, pal["roof"].darkened(0.15), pal, 6.0)
		var r := minf(w, d) * 0.30
		# dish as a top-down circle with rotating sweep
		draw_circle(Vector2(x, y - d * 0.05), r + 1.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(x, y - d * 0.05), r, pal["roof"].lightened(0.05))
		draw_arc(Vector2(x, y - d * 0.05), r, 0, TAU, 24, pal["roof"].darkened(0.3), 1.4)
		var ang := _time * 1.3 + float(seed)
		draw_line(Vector2(x, y - d * 0.05),
			Vector2(x, y - d * 0.05) + Vector2(cos(ang), sin(ang)) * r,
			Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.55), 1.6)
		draw_circle(Vector2(x, y - d * 0.05), r * 0.16, pal["roof"].darkened(0.3))

	func _paint_tanks(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var n := 2 + int(_h(seed, 1) * 3.0)
		var r := minf(w / float(n) * 0.42, d * 0.30)
		var accent: Color = pal["accent"]
		# pipe run behind the tanks
		draw_line(Vector2(x - w * 0.45, y), Vector2(x + w * 0.45, y), pal["wall"].darkened(0.1), 2.5)
		for i in n:
			var tx := x - w * 0.5 + w * (float(i) + 0.5) / float(n)
			draw_circle(Vector2(tx + 2.0, y + 2.0), r, Color(0, 0, 0, 0.35))
			draw_circle(Vector2(tx, y), r, pal["roof"].lightened(0.02))
			draw_arc(Vector2(tx, y), r, 0, TAU, 18, pal["roof"].darkened(0.28), 1.4)
			draw_circle(Vector2(tx, y), r * 0.30, pal["roof"].darkened(0.2))
			draw_arc(Vector2(tx, y), r * 0.30, 0, TAU, 10, Color(accent.r, accent.g, accent.b, 0.4), 1.0)
			draw_line(Vector2(tx, y - r), Vector2(tx, y - r * 2.0), pal["wall"].darkened(0.15), 1.6)

	func _paint_refinery(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		_footprint(x, y, w * 0.7, d * 0.7, pal["roof"].darkened(0.18), pal, 6.0)
		var accent: Color = pal["accent"]
		# pipe lattice across the lot
		for i in 3:
			var py := y - d * 0.4 + d * 0.8 * float(i) / 2.0
			draw_line(Vector2(x - w * 0.5, py), Vector2(x + w * 0.5, py), pal["roof"].darkened(0.1), 1.6)
		for i in 2:
			var px := x - w * 0.3 + w * 0.6 * float(i)
			draw_line(Vector2(px, y - d * 0.5), Vector2(px, y + d * 0.5), pal["roof"].darkened(0.1), 1.6)
		# columns / stacks with flame
		for i in 2:
			var cx := x + (float(i) - 0.5) * w * 0.5
			draw_circle(Vector2(cx, y - d * 0.1), w * 0.09, pal["roof"].lightened(0.06))
			draw_circle(Vector2(cx, y - d * 0.1), w * 0.045, pal["roof"].darkened(0.3))
			if not GameState.reduce_flashes:
				var f := 0.7 + 0.3 * sin(_time * 10.0 + float(seed + i))
				draw_circle(Vector2(cx, y - d * 0.1 - w * 0.12), w * 0.05 * f, Color(1.0, 0.6, 0.25, 0.8))
		if not GameState.reduce_flashes:
			_smoke(x, y - d * 0.3, w * 0.1)

	func _paint_turret(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var r := minf(w, d) * 0.28
		draw_circle(Vector2(x + 2.0, y + 2.0), r, Color(0, 0, 0, 0.35))
		draw_circle(Vector2(x, y), r, pal["roof"].darkened(0.22))
		draw_arc(Vector2(x, y), r, 0, TAU, 18, pal["roof"].darkened(0.4), 1.4)
		draw_circle(Vector2(x, y), r * 0.62, pal["roof"].lightened(0.05))
		var ang := _time * 0.8 + float(seed) * 0.7
		draw_line(Vector2(x, y), Vector2(x, y) + Vector2(cos(ang), sin(ang)) * r * 1.5, pal["wall"].darkened(0.05), 3.0)
		draw_circle(Vector2(x, y), 2.0, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.8))

	func _paint_pad(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var pw := w * 0.9
		var pd := d * 0.9
		draw_rect(Rect2(x - pw * 0.5, y - pd * 0.5, pw, pd), pal["ground"].darkened(0.10))
		draw_rect(Rect2(x - pw * 0.5, y - pd * 0.5, pw, pd), Color(1, 1, 1, 0.02))
		draw_arc(Vector2(x, y), minf(pw, pd) * 0.42, 0, TAU, 28, Color(1, 1, 1, 0.14), 2.0)
		# H marking
		var hs := minf(pw, pd) * 0.30
		draw_rect(Rect2(x - hs * 0.5, y - hs * 0.5, hs * 0.16, hs), Color(1, 1, 1, 0.20))
		draw_rect(Rect2(x + hs * 0.34, y - hs * 0.5, hs * 0.16, hs), Color(1, 1, 1, 0.20))
		draw_rect(Rect2(x - hs * 0.5, y - hs * 0.08, hs, hs * 0.16), Color(1, 1, 1, 0.20))
		# edge lights
		for i in 8:
			var a := TAU * float(i) / 8.0
			var lx := x + cos(a) * minf(pw, pd) * 0.42
			var ly := y + sin(a) * minf(pw, pd) * 0.42
			var blink := 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 3.0 + float(seed + i)))
			draw_circle(Vector2(lx, ly), 1.6, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.4 if GameState.reduce_flashes else blink))
		# one parked craft
		draw_rect(Rect2(x - w * 0.16, y - d * 0.20, w * 0.12, d * 0.30), pal["roof"].lightened(0.10))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + w * 0.08, y - d * 0.16), Vector2(x + w * 0.24, y), Vector2(x + w * 0.08, y + d * 0.16), Vector2(x + w * 0.02, y),
		]), pal["roof"].darkened(0.18))

	func _paint_comm(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		_footprint(x, y, w * 0.6, d * 0.5, pal["roof"].darkened(0.15), pal, 5.0)
		var accent: Color = pal["accent"]
		for i in 4:
			var px := x - w * 0.35 + w * 0.7 * float(i) / 3.0
			var py := y + d * 0.28 * (1.0 if i % 2 == 0 else -1.0)
			var r := w * 0.07
			draw_circle(Vector2(px, py), r, pal["roof"].lightened(0.06))
			draw_arc(Vector2(px, py), r, 0, TAU, 12, pal["roof"].darkened(0.3), 1.0)
			draw_circle(Vector2(px, py), r * 0.3, Color(accent.r, accent.g, accent.b, 0.5))
			var blink := 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 4.0 + float(seed + i)))
			draw_circle(Vector2(px, py), 1.4, Color(1.0, 0.3, 0.25, 0.45 if GameState.reduce_flashes else blink))

	func _paint_crane(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		# rail tracks + gantry beam with a moving trolley
		draw_line(Vector2(x - w * 0.5, y - d * 0.32), Vector2(x + w * 0.5, y - d * 0.32), pal["roof"].darkened(0.3), 3.0)
		draw_line(Vector2(x - w * 0.5, y + d * 0.32), Vector2(x + w * 0.5, y + d * 0.32), pal["roof"].darkened(0.3), 3.0)
		draw_rect(Rect2(x - w * 0.5, y - d * 0.06, w, d * 0.12), pal["roof"].lightened(0.05))
		draw_rect(Rect2(x - w * 0.5, y - d * 0.06, w, 2.0), pal["roof"].lightened(0.20))
		var tp := 0.5 + 0.4 * sin(_time * 0.5 + float(seed))
		var tx := x - w * 0.5 + w * tp
		draw_rect(Rect2(tx - 5.0, y - d * 0.12, 10.0, d * 0.24), pal["roof"].darkened(0.15))
		draw_line(Vector2(tx, y), Vector2(tx, y + d * 0.4), pal["wall"].darkened(0.2), 1.2)

	func _paint_junk(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var accent: Color = pal["accent"]
		var n := 5 + int(_h(seed, 1) * 4.0)
		for i in n:
			var jx := x + _lerp_h(seed, i * 3 + 1, -w * 0.42, w * 0.42)
			var jy := y + _lerp_h(seed, i * 3 + 2, -d * 0.42, d * 0.42)
			var s := _lerp_h(seed, i * 3 + 3, 5.0, 13.0)
			var rot := _h(seed, i * 3 + 4) * TAU
			var pts := PackedVector2Array()
			for k in 5:
				var a := rot + TAU * float(k) / 5.0
				pts.append(Vector2(jx + cos(a) * s, jy + sin(a) * s * 0.7))
			draw_colored_polygon(pts, pal["roof"].darkened(0.10 + 0.2 * _h(seed, i)))
			draw_polyline(pts + PackedVector2Array([pts[0]]), pal["wall"].darkened(0.2), 1.0)
		if _h(seed, 99) > 0.5:
			draw_rect(Rect2(x - 3.0, y - d * 0.46, 6.0, 10.0), Color(0.6, 0.35, 0.2, 0.9))
			draw_circle(Vector2(x, y - d * 0.46 + 2.0), 2.0, Color(accent.r, accent.g, accent.b, 0.5))

	func _paint_crater(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var r := minf(w, d) * 0.40
		draw_circle(Vector2(x, y), r, pal["ground"].darkened(0.35))
		draw_arc(Vector2(x, y), r, 0, TAU, 26, pal["ground"].lightened(0.12), 2.0)
		draw_circle(Vector2(x, y), r * 0.6, pal["ground"].darkened(0.5))
		for i in 4:
			var a := float(seed % 7) + TAU * float(i) / 4.0
			draw_circle(Vector2(x + cos(a) * r * 1.2, y + sin(a) * r * 1.2), 2.5, pal["ground"].darkened(0.2))

	func _paint_dome(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var r := minf(w, d) * 0.42
		draw_circle(Vector2(x + 3.0, y + 3.0), r, Color(0, 0, 0, 0.32))
		draw_circle(Vector2(x, y), r, pal["roof"])
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_line(Vector2(x, y), Vector2(x + cos(a) * r, y + sin(a) * r), pal["roof"].darkened(0.18), 1.0)
		draw_circle(Vector2(x, y), r * 0.28, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.30))
		draw_arc(Vector2(x, y), r, 0, TAU, 24, pal["roof"].lightened(0.2), 1.6)

	func _paint_crystal(x: float, y: float, w: float, d: float, seed: int, pal: Dictionary) -> void:
		var accent: Color = pal["accent"]
		for i in 3:
			var s := minf(w, d) * (0.30 - float(i) * 0.06)
			var cxp := x + (float(i) - 1.0) * w * 0.22
			var pts := PackedVector2Array([
				Vector2(cxp, y - s), Vector2(cxp + s * 0.6, y), Vector2(cxp, y + s), Vector2(cxp - s * 0.6, y),
			])
			draw_colored_polygon(pts, pal["roof"].lightened(0.05 + 0.05 * float(i)))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(accent.r, accent.g, accent.b, 0.6), 1.2)
		draw_circle(Vector2(x, y), minf(w, d) * 0.18, Color(accent.r, accent.g, accent.b, 0.35))

	func _smoke(x: float, y: float, scale: float) -> void:
		for i in 4:
			var rise := fmod(_time * 0.25 + float(i) * 0.25, 1.0)
			draw_circle(Vector2(x + sin(_time * 0.6 + float(i) * 2.0) * scale, y - rise * scale * 8.0),
				scale * (0.6 + rise * 1.2), Color(0.45, 0.44, 0.42, 0.16 * (1.0 - rise)))


# ===========================================================================
# Cloud deck — translucent clouds sliding over the base, each with a shadow.
# ===========================================================================
class _CloudLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var _style: StringName = &"city"
	var clouds: Array[Dictionary] = []
	var _rng: RandomNumberGenerator
	var _time: float = 0.0

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		clouds.clear()
		for i in 3:
			clouds.append({
				"x": rng.randf() * vp.x, "y": rng.randf() * vp.y,
				"r": rng.randf_range(90.0, 170.0), "seed": rng.randi(),
			})

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func set_style(s: StringName) -> void:
		_style = s
		queue_redraw()

	func tick(delta: float, speed: float, vp: Vector2) -> void:
		_time += delta
		for i in clouds.size():
			var c: Dictionary = clouds[i]
			c["y"] = float(c["y"]) + speed * delta
			if float(c["y"]) - float(c["r"]) > vp.y + 40.0:
				c["y"] = -float(c["r"]) - 40.0
				c["x"] = _rng.randf() * vp.x
				c["r"] = _rng.randf_range(70.0, 150.0)
				c["seed"] = _rng.randi()
			clouds[i] = c
		queue_redraw()

	func _draw() -> void:
		for raw in clouds:
			var c: Dictionary = raw
			var x := float(c["x"])
			var y := float(c["y"])
			var r := float(c["r"])
			var seed := int(c["seed"])
			# soft shadow on the ground
			draw_circle(Vector2(x + 12.0, y + 16.0), r * 0.85, Color(0, 0, 0, 0.045))
			# cloud body — a couple of soft overlapping lobes
			for i in 3:
				var a := float(seed % 11) + TAU * float(i) / 3.0
				var ox := cos(a) * r * 0.40
				var oy := sin(a) * r * 0.24
				draw_circle(Vector2(x + ox, y + oy), r * 0.55, Color(0.78, 0.81, 0.86, 0.030))
			draw_circle(Vector2(x, y), r * 0.5, Color(0.84, 0.86, 0.9, 0.025))


# ===========================================================================
# Foreground — debris, embers and smoke close to the camera.
# ===========================================================================
class _ForegroundLayer extends Node2D:
	var tint: Color = Color(0.12, 0.16, 0.38)
	var debris: Array[Dictionary] = []
	var embers: Array[Vector3] = []
	var puffs: Array[Vector3] = []
	var _rng: RandomNumberGenerator
	var _time: float = 0.0

	func setup(vp: Vector2, t: Color, rng: RandomNumberGenerator) -> void:
		tint = t
		_rng = rng
		debris.clear()
		embers.clear()
		puffs.clear()
		for i in 7:
			_spawn_debris(vp, rng.randf() * vp.y)
		for i in 10:
			embers.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(1.0, 2.4)))
		for i in 3:
			puffs.append(Vector3(rng.randf() * vp.x, rng.randf() * vp.y, rng.randf_range(70.0, 130.0)))

	func on_resize(_vp: Vector2) -> void:
		queue_redraw()

	func _spawn_debris(vp: Vector2, y: float) -> void:
		debris.append({
			"pos": Vector2(_rng.randf() * vp.x, y),
			"rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-2.5, 2.5),
			"pts": _make_shard(_rng.randf_range(5.0, 14.0)),
		})

	func _make_shard(r: float) -> PackedVector2Array:
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
				d["pts"] = _make_shard(_rng.randf_range(5.0, 14.0))
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
			draw_circle(Vector2(p.x, p.y), p.z * 0.5, Color(0.06, 0.06, 0.08, 0.30))
			draw_circle(Vector2(p.x + p.z * 0.3, p.y + 8.0), p.z * 0.38, Color(0.05, 0.05, 0.07, 0.26))
		for e in embers:
			var tw := 0.5 + 0.5 * sin(_time * 6.0 + float(e.z) * 9.0)
			draw_circle(Vector2(e.x, e.y), e.z, Color(1.0, 0.55, 0.25, 0.30 + 0.5 * tw))
		for d in debris:
			var pos: Vector2 = d["pos"]
			var rot: float = d["rot"]
			var pts: PackedVector2Array = d["pts"]
			var xform := Transform2D(rot, pos)
			var world := PackedVector2Array()
			for p in pts:
				world.append(xform * p)
			draw_colored_polygon(world, Color(0.5, 0.48, 0.46, 0.5))
			if world.size() >= 2:
				draw_polyline(world + PackedVector2Array([world[0]]), Color(0.85, 0.8, 0.75, 0.35), 1.0)
