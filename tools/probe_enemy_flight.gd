extends SceneTree
## Dev probe: simulates a formation flying each side-entry pass and reports
## whether it stays coherent, becomes visible, and clears the screen.
## Run: godot --headless --path . --script res://tools/probe_enemy_flight.gd

const DT := 1.0 / 60.0
const DURATION := 12.0
const PATTERNS: Array[StringName] = [&"loop", &"sweep", &"arc", &"hover_dart", &"dive"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://scenes/entities/enemy_base.tscn")
	var stats: EnemyStats = load("res://resources/enemies/scout.tres")
	if scene == null or stats == null:
		push_error("probe: missing scene or stats")
		quit(1)
		return
	for pat in PATTERNS:
		_probe(scene, stats, pat)
	print("PROBE DONE")
	quit(0)


func _probe(scene: PackedScene, stats: EnemyStats, pat: StringName) -> void:
	var vp := root.get_visible_rect().size
	var slots := SpawnEntry.pattern_offsets(&"v", 5, 56.0)
	var anchor := Vector2(vp.x * 0.5 - vp.x * 0.30, vp.y * 0.40)
	var enemies: Array = []
	for slot in slots:
		var e: Node = scene.instantiate()
		root.add_child(e)
		e.global_position = anchor + slot
		e.setup(stats, null, 40.0, "probe", pat, slot, 0.7, 112.0)
		e.call("_side_spawn_setup")
		enemies.append(e)

	var t := 0.0
	var entered := false
	var peak_visible := 0
	var rigid_drift := 0.0
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var last_visible_t := -1.0
	var first_visible_t := -1.0
	while t < DURATION:
		for e in enemies:
			if is_instance_valid(e):
				e._move(DT)
		var anchor0: Vector2 = enemies[0].global_position - slots[0]
		var vis := 0
		for i in enemies.size():
			var e = enemies[i]
			var a: Vector2 = e.global_position - slots[i]
			rigid_drift = maxf(rigid_drift, a.distance_to(anchor0))
			var p: Vector2 = e.global_position
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
			if p.x > 0.0 and p.x < vp.x and p.y > 0.0 and p.y < vp.y:
				vis += 1
		if vis > 0:
			entered = true
			if first_visible_t < 0.0:
				first_visible_t = t
			last_visible_t = t
		peak_visible = maxi(peak_visible, vis)
		t += DT

	# Rigid formations should hold their slots exactly (drift ~ 0).
	var rigid := rigid_drift < 1.0
	print("%-11s entered=%s first_vis=%.2fs last_vis=%.2fs peak=%d rigid=%s (drift=%.2f) x=[%.0f,%.0f] y=[%.0f,%.0f] vp=[%.0f,%.0f]" % [
		pat, entered, first_visible_t, last_visible_t, peak_visible, rigid, rigid_drift,
		min_x, max_x, min_y, max_y, vp.x, vp.y
	])
	for e in enemies:
		if is_instance_valid(e):
			e.free()
