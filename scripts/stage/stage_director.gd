extends Node
## Enables the active mission's stage gimmick and drives its runtime hazards.

var mission: MissionData
var player: Node
var pool: ProjectilePool
var entities: Node2D
var formation_tracker: Node

var _gimmick: StringName = &""
var _timer: float = 0.0
var _pulse: float = 0.0
var _rng := RandomNumberGenerator.new()
var _nebula_fog: ColorRect
var _barriers: Array[Node] = []
var _singularities: Array[Node] = []


func setup(p_player: Node, p_pool: ProjectilePool, p_entities: Node2D, tracker: Node) -> void:
	player = p_player
	pool = p_pool
	entities = p_entities
	formation_tracker = tracker
	_rng.randomize()


func begin(data: MissionData) -> void:
	mission = data
	_gimmick = data.gimmick_id if data else &""
	_timer = 0.0
	_pulse = 2.0
	_clear_runtime()
	match _gimmick:
		&"formations":
			EventBus.gimmick_toast.emit("CHAIN FORMATIONS")
		&"asteroids":
			EventBus.gimmick_toast.emit("SPLITTING ROCKS")
		&"nebula":
			EventBus.gimmick_toast.emit("NEBULA ANOMALY")
			_ensure_fog()
		&"hive":
			EventBus.gimmick_toast.emit("LASER CORRIDORS")
		&"gravity":
			EventBus.gimmick_toast.emit("SINGULARITIES")
		_:
			pass


func stop() -> void:
	_gimmick = &""
	mission = null
	_clear_runtime()


func _clear_runtime() -> void:
	for b in _barriers:
		if is_instance_valid(b):
			b.queue_free()
	_barriers.clear()
	for s in _singularities:
		if is_instance_valid(s):
			s.queue_free()
	_singularities.clear()
	if _nebula_fog and is_instance_valid(_nebula_fog):
		_nebula_fog.queue_free()
		_nebula_fog = null
	if player and player.has_method("clear_zone_effects"):
		player.clear_zone_effects()
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if mission == null or _gimmick == &"":
		return
	_timer += delta
	_pulse -= delta
	match _gimmick:
		&"nebula":
			_tick_nebula(delta)
		&"hive":
			_tick_hive(delta)
		&"gravity":
			_tick_gravity(delta)


func _ensure_fog() -> void:
	if _nebula_fog:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_nebula_fog = ColorRect.new()
	_nebula_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nebula_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nebula_fog.color = Color(0.45, 0.2, 0.55, 0.0)
	layer.add_child(_nebula_fog)


func _tick_nebula(delta: float) -> void:
	# Pulse obscuring fog across the lower playfield.
	if _nebula_fog:
		var pulse := 0.55 + 0.45 * sin(_timer * 0.7)
		_nebula_fog.color.a = 0.08 + 0.22 * pulse
		# Cover lower 45% of screen via offset.
		var vp := get_viewport().get_visible_rect().size
		_nebula_fog.offset_top = vp.y * (0.45 + 0.08 * sin(_timer * 0.5))
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(4.5, 7.0)
		_spawn_plasma_pool()


func _spawn_plasma_pool() -> void:
	if entities == null:
		return
	var zone_script: Script = load("res://scripts/stage/drifting_zone.gd")
	var zone := Area2D.new()
	zone.set_script(zone_script)
	zone.add_to_group("plasma_zones")
	zone.collision_layer = 0
	zone.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	zone.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.6, 1.0, 0.85, 0.35)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 48.0)
	poly.polygon = pts
	zone.add_child(poly)
	entities.add_child(zone)
	zone.scroll_speed = (mission.scroll_speed if mission else 45.0) * 0.9
	var vp := get_viewport().get_visible_rect().size
	zone.global_position = Vector2(_rng.randf_range(60.0, vp.x - 60.0), -40.0)
	zone.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player") and b.has_method("enter_plasma"):
			b.enter_plasma()
	)
	zone.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player") and b.has_method("exit_plasma"):
			b.exit_plasma()
	)


func _tick_hive(_delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(6.5, 10.0)
		_spawn_barrier_pair()
		if _rng.randf() < 0.7:
			_spawn_terminal()


func _spawn_barrier_pair() -> void:
	var scene: PackedScene = load("res://scenes/stage/barrier.tscn")
	if scene == null or entities == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var gap_x := _rng.randf_range(vp.x * 0.25, vp.x * 0.75)
	var gap_w := 120.0
	for side in [-1, 1]:
		var b: Node = scene.instantiate()
		entities.add_child(b)
		_barriers.append(b)
		if b.has_method("setup"):
			var x0 := 0.0 if side < 0 else gap_x + gap_w * 0.5
			var x1 := gap_x - gap_w * 0.5 if side < 0 else vp.x
			b.setup(Vector2(x0, -20.0), Vector2(x1, -20.0), mission.scroll_speed if mission else 50.0)


func _spawn_terminal() -> void:
	var scene: PackedScene = load("res://scenes/stage/terminal.tscn")
	if scene == null or entities == null:
		return
	var t: Node = scene.instantiate()
	entities.add_child(t)
	var vp := get_viewport().get_visible_rect().size
	t.global_position = Vector2(_rng.randf_range(80.0, vp.x - 80.0), -30.0)
	if t.has_method("setup"):
		t.setup(pool, mission.scroll_speed if mission else 50.0)


func _tick_gravity(delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(8.0, 12.0)
		_spawn_singularity()
	# Bend enemy bullets toward singularities.
	if pool == null:
		return
	for s in _singularities:
		if not is_instance_valid(s):
			continue
		var center: Vector2 = s.global_position
		var strength: float = float(s.get("pull_strength")) if s.get("pull_strength") != null else 120.0
		for proj in pool.get_active_enemy_projectiles():
			var to: Vector2 = center - proj.global_position
			var d2: float = to.length_squared()
			if d2 < 40.0 or d2 > 200.0 * 200.0:
				continue
			var pull: Vector2 = to.normalized() * (strength * 50.0 / d2) * delta * 3200.0
			if "velocity" in proj:
				proj.velocity += pull
		if player and is_instance_valid(player) and not player.dead:
			var to_p: Vector2 = center - player.global_position
			var pd2: float = to_p.length_squared()
			if pd2 > 36.0 and pd2 < 180.0 * 180.0:
				player.global_position += to_p.normalized() * (70.0 / sqrt(pd2)) * delta * 32.0


func _spawn_singularity() -> void:
	var scene: PackedScene = load("res://scenes/stage/singularity.tscn")
	if scene == null or entities == null:
		return
	var s: Node = scene.instantiate()
	entities.add_child(s)
	_singularities.append(s)
	var vp := get_viewport().get_visible_rect().size
	s.global_position = Vector2(_rng.randf_range(100.0, vp.x - 100.0), vp.y * 0.35)
	if s.has_method("setup"):
		s.setup(player)
