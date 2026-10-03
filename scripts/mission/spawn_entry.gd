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
## Geometric layout: line, column, v, inv_v, wedge, diamond, arc, box, cross,
## wave, circle, ring, star, spiral, chevron, echelon, arrow, wall, wedge2,
## hourglass, scattered, pincer, block.
@export var pattern: StringName = &"line"
## Distance between members in named patterns (pixels).
@export var pattern_spread: float = 52.0
## Optional per-entry flight override (e.g. &"pendulum", &"charge", &"s_curve").
## If set, overrides EnemyStats.flight_pattern for this entry.
@export var flight_pattern: StringName = &""


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
		"circle", "ring":
			_fill_circle(out, n, spread)
		"star":
			_fill_star(out, n, spread)
		"spiral":
			_fill_spiral(out, n, spread)
		"chevron":
			_fill_chevron(out, n, spread)
		"wave":
			for i in n:
				out.append(Vector2(float(i) * spread, sin(float(i) * 1.1) * spread * 0.65))
		"echelon":
			for i in n:
				out.append(Vector2(float(i) * spread * 0.85, float(i) * spread * 0.45))
		"arrow":
			var arrow_mid := (n - 1) * 0.5
			for i in n:
				var d := float(i) - arrow_mid
				out.append(Vector2(absf(d) * spread * 0.5, d * spread * 0.55))
		"wall":
			for i in n:
				var x := float(i % 2) * spread - spread * 0.5
				var y := float(i / 2) * spread * 0.5
				if i % 2 == 1:
					y += spread * 0.25
				out.append(Vector2(x, y))
		"wedge2":
			var w2_mid := (n - 1) * 0.5
			for i in n:
				var d := float(i) - w2_mid
				out.append(Vector2(d * spread, absf(d) * spread * 0.35))
		"hourglass":
			for i in n:
				var t := float(i) / float(maxi(n - 1, 1))
				var x := (1.0 - absf(t - 0.5) * 2.0) * spread * 0.9
				var y := (t - 0.5) * spread * 2.2
				var flip := 1.0 if i % 2 == 0 else -1.0
				out.append(Vector2(x * flip, y))
		"scattered":
			for i in n:
				var a := TAU * float(i) / float(n) + 0.7 * float(i)
				var r := spread * (0.4 + 0.6 * randf())
				out.append(Vector2(cos(a), sin(a) * 0.55) * r)
		"pincer":
			var half := n / 2
			for i in n:
				var side := -1.0 if i < half else 1.0
				var row := i % half
				out.append(Vector2(side * (spread + float(row) * spread * 0.5), float(row) * spread * 0.55))
		"block":
			var bcols := 2 if n <= 6 else 3
			var brows := ceili(float(n) / float(bcols))
			var bi := 0
			for r in brows:
				for c in bcols:
					if bi >= n:
						break
					out.append(Vector2((float(c) - (bcols - 1) * 0.5) * spread, float(r) * spread * 0.7))
					bi += 1
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


static func _fill_circle(out: Array[Vector2], n: int, spread: float) -> void:
	## Even ring, first member at the top (facing the player).
	var radius := spread * (0.9 + float(n) * 0.14)
	for i in n:
		var a := TAU * float(i) / float(n) - PI * 0.5
		out.append(Vector2(cos(a), sin(a)) * radius)


static func _fill_star(out: Array[Vector2], n: int, spread: float) -> void:
	## Alternating outer/inner radius reads as a star or sparkle.
	var outer := spread * (1.4 + float(n) * 0.12)
	var inner := outer * 0.42
	for i in n:
		var a := TAU * float(i) / float(n) - PI * 0.5
		var r := outer if i % 2 == 0 else inner
		out.append(Vector2(cos(a), sin(a)) * r)


static func _fill_spiral(out: Array[Vector2], n: int, spread: float) -> void:
	## Members unwind outward from the center in ~1.25 turns.
	var turns := 1.25
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var a := t * TAU * turns - PI * 0.5
		var r := spread * t * (1.4 + float(n) * 0.2)
		out.append(Vector2(cos(a), sin(a)) * r)


static func _fill_chevron(out: Array[Vector2], n: int, spread: float) -> void:
	## Stacked V rows — rows get wider behind the leader (classic bomber wedge).
	var i := 0
	var row := 0
	while i < n:
		var width := row + 1
		var mid := float(width - 1) * 0.5
		for j in width:
			if i >= n:
				return
			var d := float(j) - mid
			out.append(Vector2(d * spread, float(row) * spread * 0.9))
			i += 1
		row += 1
