class_name SpawnEntry
extends Resource
## One enemy spawn within a wave. Use `pattern` for geometric layouts.

@export var enemy: EnemyStats
@export var delay: float = 0.0
@export var position: Vector2 = Vector2(240, -40)
@export var count: int = 1
## Used when pattern is `line` or `column` (legacy linear offset).
@export var spacing: Vector2 = Vector2(40, 0)
## Non-empty = all units in this entry share a formation for chain-reaction clears.
@export var formation_id: String = ""
## Geometric layout: line, column, v, inv_v, wedge, diamond, arc, box, cross, wave.
@export var pattern: StringName = &"line"
## Distance between members in named patterns (pixels).
@export var pattern_spread: float = 52.0


func offsets() -> Array[Vector2]:
	return pattern_offsets(pattern, count, pattern_spread, spacing)


static func pattern_offsets(
	pat: StringName,
	n: int,
	spread: float = 52.0,
	legacy_spacing: Vector2 = Vector2(48, 0)
) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if n <= 0:
		return out
	if n == 1:
		out.append(Vector2.ZERO)
		return out

	match String(pat):
		"column":
			for i in n:
				out.append(Vector2(0.0, float(i) * spread))
		"v", "wedge":
			# Point of the V at the front (toward player / +Y).
			var mid := (n - 1) * 0.5
			for i in n:
				var d := float(i) - mid
				out.append(Vector2(d * spread, -absf(d) * spread * 0.55))
		"inv_v":
			var mid := (n - 1) * 0.5
			for i in n:
				var d := float(i) - mid
				out.append(Vector2(d * spread, absf(d) * spread * 0.55))
		"diamond":
			_fill_diamond(out, n, spread)
		"arc":
			# Downward-facing arc (ships enter as a curved front).
			var span := PI * 0.85
			var start := PI * 0.5 - span * 0.5
			var radius := spread * maxf(1.2, float(n) * 0.55)
			for i in n:
				var t := start + span * (float(i) / float(n - 1))
				out.append(Vector2(cos(t), -sin(t)) * radius)
		"box":
			_fill_box(out, n, spread)
		"cross":
			_fill_cross(out, n, spread)
		"wave":
			for i in n:
				out.append(Vector2(float(i) * spread, sin(float(i) * 1.1) * spread * 0.65))
		_:
			# line (default) — honour legacy spacing vector
			for i in n:
				out.append(legacy_spacing * float(i))
	return out


static func _fill_diamond(out: Array[Vector2], n: int, spread: float) -> void:
	# Ring order: center (if odd) then clockwise diamond vertices / edges.
	if n == 1:
		out.append(Vector2.ZERO)
		return
	var pts: Array[Vector2] = [
		Vector2(0, -spread),
		Vector2(spread, 0),
		Vector2(0, spread),
		Vector2(-spread, 0),
	]
	if n >= 5:
		pts.append(Vector2.ZERO)
	# Extra members along edges for larger groups.
	var edge_extra := [
		Vector2(spread * 0.5, -spread * 0.5),
		Vector2(spread * 0.5, spread * 0.5),
		Vector2(-spread * 0.5, spread * 0.5),
		Vector2(-spread * 0.5, -spread * 0.5),
	]
	for p in edge_extra:
		pts.append(p)
	for i in mini(n, pts.size()):
		out.append(pts[i])
	while out.size() < n:
		var i := out.size()
		out.append(Vector2(float(i % 3 - 1) * spread * 0.4, float(i / 3) * spread * 0.35))


static func _fill_box(out: Array[Vector2], n: int, spread: float) -> void:
	var cols := ceili(sqrt(float(n)))
	var rows := ceili(float(n) / float(cols))
	var i := 0
	for r in rows:
		for c in cols:
			if i >= n:
				return
			out.append(Vector2(
				(float(c) - (cols - 1) * 0.5) * spread,
				(float(r) - (rows - 1) * 0.5) * spread * 0.85
			))
			i += 1


static func _fill_cross(out: Array[Vector2], n: int, spread: float) -> void:
	out.append(Vector2.ZERO)
	var dirs: Array[Vector2] = [
		Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0),
		Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0),
	]
	for d in dirs:
		if out.size() >= n:
			return
		out.append(d * spread)
	while out.size() < n:
		out.append(Vector2(float(out.size()) * spread * 0.3, -spread))
