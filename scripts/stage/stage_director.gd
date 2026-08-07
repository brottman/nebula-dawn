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
var _runtime: Array[Node] = []
var _flare_overlay: ColorRect

## Endless mode rotates through a hazard-safe gimmick subset on a timer.
const ENDLESS_GIMMICKS: Array[StringName] = [
	&"nebula", &"mirrors", &"ion", &"phantoms", &"scrap", &"hive", &"gravity", &"flare",
]
const ENDLESS_FIRST_ROTATE := 20.0
const ENDLESS_ROTATE_INTERVAL := 45.0
var _endless_mode: bool = false
var _rotate_timer: float = 0.0


func setup(p_player: Node, p_pool: ProjectilePool, p_entities: Node2D, tracker: Node) -> void:
	player = p_player
	pool = p_pool
	entities = p_entities
	formation_tracker = tracker
	_rng.randomize()


func begin(data: MissionData) -> void:
	mission = data
	_endless_mode = false
	_timer = 0.0
	_pulse = 2.0
	_clear_runtime()
	_activate_gimmick(data.gimmick_id if data else &"")


func begin_endless() -> void:
	mission = null
	_endless_mode = true
	_timer = 0.0
	_pulse = 2.0
	_rotate_timer = ENDLESS_FIRST_ROTATE
	_clear_runtime()
	_gimmick = &""
	EventBus.gimmick_toast.emit("ANOMALIES INBOUND")


func stop() -> void:
	_gimmick = &""
	_endless_mode = false
	mission = null
	_clear_runtime()


func _activate_gimmick(g: StringName) -> void:
	_clear_runtime()
	_gimmick = g
	_pulse = 2.0
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
		&"mirrors":
			EventBus.gimmick_toast.emit("MIRROR FIELD")
		&"ion":
			EventBus.gimmick_toast.emit("ION STORM")
		&"phantoms":
			EventBus.gimmick_toast.emit("PHANTOM WAKE")
			_ensure_fog(Color(0.2, 0.35, 0.55, 0.0))
		&"scrap":
			EventBus.gimmick_toast.emit("SCRAP CONVEYORS")
		&"flare":
			EventBus.gimmick_toast.emit("DAWN FLARES")
		_:
			pass


func _rotate_gimmick() -> void:
	var options: Array[StringName] = []
	for g in ENDLESS_GIMMICKS:
		if g != _gimmick:
			options.append(g)
	if options.is_empty():
		return
	_activate_gimmick(options[_rng.randi() % options.size()])


func _clear_runtime() -> void:
	for b in _barriers:
		if is_instance_valid(b):
			b.queue_free()
	_barriers.clear()
	for s in _singularities:
		if is_instance_valid(s):
			s.queue_free()
	_singularities.clear()
	for n in _runtime:
		if is_instance_valid(n):
			n.queue_free()
	_runtime.clear()
	if _nebula_fog and is_instance_valid(_nebula_fog):
		_nebula_fog.queue_free()
		_nebula_fog = null
	if _flare_overlay and is_instance_valid(_flare_overlay):
		_flare_overlay.queue_free()
		_flare_overlay = null
	if player and player.has_method("clear_zone_effects"):
		player.clear_zone_effects()
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _endless_mode:
		_rotate_timer -= delta
		if _rotate_timer <= 0.0:
			_rotate_timer = ENDLESS_ROTATE_INTERVAL
			_rotate_gimmick()
	if _gimmick == &"" or (mission == null and not _endless_mode):
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
		&"mirrors":
			_tick_mirrors(delta)
		&"ion":
			_tick_ion(delta)
		&"phantoms":
			_tick_phantoms(delta)
		&"scrap":
			_tick_scrap(delta)
		&"flare":
			_tick_flare(delta)


func _ensure_fog(color: Color = Color(0.45, 0.2, 0.55, 0.0)) -> void:
	if _nebula_fog:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_nebula_fog = ColorRect.new()
	_nebula_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nebula_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nebula_fog.color = color
	layer.add_child(_nebula_fog)


func _tick_nebula(delta: float) -> void:
	if _nebula_fog:
		var pulse := 0.55 + 0.45 * sin(_timer * 0.7)
		var amp := 0.10 if GameState.reduce_flashes else 0.22
		_nebula_fog.color.a = 0.08 + amp * pulse
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
	_runtime.append(zone)
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
	_runtime.append(t)
	var vp := get_viewport().get_visible_rect().size
	t.global_position = Vector2(_rng.randf_range(80.0, vp.x - 80.0), -30.0)
	if t.has_method("setup"):
		t.setup(pool, mission.scroll_speed if mission else 50.0)


func _tick_gravity(delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(8.0, 12.0)
		_spawn_singularity()
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


func _tick_mirrors(_delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(3.8, 6.0)
		_spawn_mirror_plate()


func _spawn_mirror_plate() -> void:
	if entities == null:
		return
	var plate := Area2D.new()
	plate.set_script(load("res://scripts/stage/mirror_plate.gd"))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 14)
	shape.shape = rect
	plate.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.55, 0.85, 1.0, 0.7)
	poly.polygon = PackedVector2Array([
		Vector2(-35, -7), Vector2(35, -7), Vector2(35, 7), Vector2(-35, 7)
	])
	plate.add_child(poly)
	entities.add_child(plate)
	_runtime.append(plate)
	var vp := get_viewport().get_visible_rect().size
	plate.global_position = Vector2(_rng.randf_range(70.0, vp.x - 70.0), -30.0)
	if plate.has_method("setup"):
		plate.setup(mission.scroll_speed if mission else 52.0)


func _tick_ion(_delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(3.2, 5.2)
		_spawn_ion_column()


func _spawn_ion_column() -> void:
	if entities == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var x := _rng.randf_range(50.0, vp.x - 50.0)
	var bolt := Area2D.new()
	bolt.collision_layer = 32
	bolt.collision_mask = 1
	bolt.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, vp.y)
	shape.shape = rect
	bolt.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.55, 0.85, 1.0, 0.45)
	poly.polygon = PackedVector2Array([
		Vector2(-10, -vp.y * 0.5), Vector2(10, -vp.y * 0.5),
		Vector2(14, vp.y * 0.5), Vector2(-14, vp.y * 0.5)
	])
	bolt.add_child(poly)
	entities.add_child(bolt)
	_runtime.append(bolt)
	bolt.global_position = Vector2(x, vp.y * 0.5)
	EventBus.gimmick_toast.emit("ION STRIKE")
	EventBus.screen_shake.emit(4.0, 0.1)
	bolt.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1)
	)
	var tw := bolt.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, 0.55)
	tw.tween_callback(bolt.queue_free)


func _tick_phantoms(delta: float) -> void:
	if _nebula_fog:
		var pulse := 0.5 + 0.5 * sin(_timer * 1.1)
		var amp := 0.07 if GameState.reduce_flashes else 0.16
		_nebula_fog.color.a = 0.06 + amp * pulse
		var vp := get_viewport().get_visible_rect().size
		_nebula_fog.offset_top = vp.y * (0.35 + 0.1 * sin(_timer * 0.7))
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(2.4, 3.8)
		_spawn_phantom_echo()


func _spawn_phantom_echo() -> void:
	if pool == null or player == null or not is_instance_valid(player) or player.dead:
		return
	var target: Vector2 = player.global_position
	# Delayed ghost volley at the player's recent lane.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if pool == null:
			return
		var muzzle := Vector2(target.x, 40.0)
		for i in 3:
			var a := -0.22 + 0.22 * float(i)
			pool.spawn_enemy(muzzle, Vector2(a, 1).normalized() * 210.0, 1.0, {
				"color": Color(0.45, 0.7, 1.0, 0.55),
				"scale": 0.85,
				"wave_amp": 12.0,
				"wave_freq": 5.0,
			})
		AudioBus.play_enemy_shoot()
		EventBus.gimmick_toast.emit("ECHO")
	)


func _tick_scrap(_delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(5.0, 7.5)
		_spawn_scrap_belt()


func _spawn_scrap_belt() -> void:
	if entities == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var dir := 1.0 if _rng.randf() > 0.5 else -1.0
	var y := _rng.randf_range(vp.y * 0.35, vp.y * 0.75)
	var belt := Area2D.new()
	belt.collision_layer = 0
	belt.collision_mask = 1
	belt.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(vp.x + 40.0, 54.0)
	shape.shape = rect
	belt.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = Color(0.85, 0.55, 0.25, 0.22)
	poly.polygon = PackedVector2Array([
		Vector2(-vp.x * 0.5, -24), Vector2(vp.x * 0.5, -24),
		Vector2(vp.x * 0.5, 24), Vector2(-vp.x * 0.5, 24)
	])
	belt.add_child(poly)
	# Motion chevrons.
	for i in 5:
		var chev := Polygon2D.new()
		chev.color = Color(1.0, 0.75, 0.35, 0.55)
		var sx := dir * 10.0
		chev.polygon = PackedVector2Array([Vector2(-sx, -8), Vector2(sx, 0), Vector2(-sx, 8)])
		chev.position = Vector2((-2 + i) * 70.0, 0)
		poly.add_child(chev)
	entities.add_child(belt)
	_runtime.append(belt)
	belt.global_position = Vector2(vp.x * 0.5, y)
	var push := dir * 160.0
	belt.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			b.set("scrap_push", push)
			EventBus.gimmick_toast.emit("CONVEYOR")
	)
	belt.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			b.set("scrap_push", 0.0)
	)
	var life := belt.create_tween()
	life.tween_interval(4.5)
	life.tween_callback(func() -> void:
		if player and is_instance_valid(player):
			player.set("scrap_push", 0.0)
		if is_instance_valid(belt):
			belt.queue_free()
	)


func _tick_flare(_delta: float) -> void:
	if _pulse <= 0.0:
		_pulse = _rng.randf_range(7.5, 11.0)
		_trigger_flare()
		if _rng.randf() < 0.45:
			_spawn_singularity()


func _trigger_flare() -> void:
	var vp := get_viewport().get_visible_rect().size
	EventBus.gimmick_toast.emit("SOLAR FLARE")
	EventBus.screen_shake.emit(7.0, 0.2)
	if _flare_overlay == null or not is_instance_valid(_flare_overlay):
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_flare_overlay = ColorRect.new()
		_flare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flare_overlay.color = Color(1.0, 0.55, 0.2, 0.0)
		layer.add_child(_flare_overlay)
	_flare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flare_overlay.offset_top = vp.y * 0.55
	var zone := Area2D.new()
	zone.collision_layer = 32
	zone.collision_mask = 1
	zone.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(vp.x, vp.y * 0.45)
	shape.shape = rect
	zone.add_child(shape)
	entities.add_child(zone)
	_runtime.append(zone)
	zone.global_position = Vector2(vp.x * 0.5, vp.y * 0.78)
	zone.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1)
	)
	var peak_alpha := 0.12 if GameState.reduce_flashes else 0.35
	var tw := create_tween()
	tw.tween_property(_flare_overlay, "color:a", peak_alpha, 0.2)
	tw.tween_interval(0.85)
	tw.tween_property(_flare_overlay, "color:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(zone):
			zone.queue_free()
	)
	# Clear enemy bullets in the upper half as the flare "washes" the field.
	if pool and pool.has_method("clear_enemy_in_radius"):
		pool.clear_enemy_in_radius(Vector2(vp.x * 0.5, vp.y * 0.25), vp.x * 0.7)