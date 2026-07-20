extends Area2D
## Base enemy / hazard with configurable movement patterns.

enum Pattern { DIVE, STRAFE, DRIFT, BOSS }

@export var stats: EnemyStats

var hp: float = 1.0
var pattern: Pattern = Pattern.DIVE
var scroll_speed: float = 40.0
var projectile_pool: ProjectilePool
var alive: bool = true

var _fire_timer: float = 0.0
var _strafe_dir: float = 1.0
var _t: float = 0.0
var _boss_phase: int = 0
var _origin_x: float = 0.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(s: EnemyStats, pool: ProjectilePool, world_scroll: float) -> void:
	stats = s
	projectile_pool = pool
	scroll_speed = world_scroll
	hp = s.max_hp
	_apply_visuals()
	_origin_x = global_position.x
	_fire_timer = s.fire_interval * 0.5
	if s.is_boss:
		pattern = Pattern.BOSS
		add_to_group("enemies")
		add_to_group("boss")
		collision_layer = 4
		collision_mask = 2 | 1
		EventBus.boss_spawned.emit(self)
		EventBus.boss_hp_changed.emit(hp, stats.max_hp)
	elif s.is_hazard:
		pattern = Pattern.DRIFT
		add_to_group("hazards")
		collision_layer = 32
		collision_mask = 1 | 2
	else:
		match String(s.enemy_id):
			"strafer":
				pattern = Pattern.STRAFE
			"drone":
				pattern = Pattern.DRIFT
			_:
				pattern = Pattern.DIVE
		add_to_group("enemies")
		collision_layer = 4
		collision_mask = 1 | 2
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0


func _apply_visuals() -> void:
	if stats == null or _poly == null:
		return
	_poly.color = stats.color
	var half := stats.size * 0.5
	match String(stats.enemy_id):
		"scout":
			_poly.polygon = PackedVector2Array([
				Vector2(0, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)
			])
		"strafer":
			_poly.polygon = PackedVector2Array([
				Vector2(-half.x, 0), Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y)
			])
		"drone":
			_poly.polygon = PackedVector2Array([
				Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)
			])
		"asteroid":
			_poly.polygon = PackedVector2Array([
				Vector2(-half.x * 0.6, -half.y), Vector2(half.x, -half.y * 0.4),
				Vector2(half.x * 0.7, half.y), Vector2(-half.x, half.y * 0.5),
				Vector2(-half.x * 0.9, -half.y * 0.2)
			])
		"boss":
			_poly.polygon = PackedVector2Array([
				Vector2(0, half.y), Vector2(-half.x, half.y * 0.2),
				Vector2(-half.x * 0.7, -half.y), Vector2(half.x * 0.7, -half.y),
				Vector2(half.x, half.y * 0.2)
			])
		_:
			_poly.polygon = PackedVector2Array([
				Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)
			])
	if _collision and _collision.shape is RectangleShape2D:
		(_collision.shape as RectangleShape2D).size = stats.size


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	_move(delta)
	_try_fire(delta)
	var vp := get_viewport_rect().size
	if global_position.y > vp.y + 80.0 and not (stats and stats.is_boss):
		queue_free()


func _move(delta: float) -> void:
	var speed := stats.move_speed if stats else 120.0
	match pattern:
		Pattern.DIVE:
			global_position.y += (speed + scroll_speed) * delta
		Pattern.STRAFE:
			global_position.y += (speed * 0.35 + scroll_speed) * delta
			global_position.x += _strafe_dir * speed * delta
			var vp := get_viewport_rect().size
			if global_position.x < 30.0 or global_position.x > vp.x - 30.0:
				_strafe_dir *= -1.0
				global_position.x = clampf(global_position.x, 30.0, vp.x - 30.0)
		Pattern.DRIFT:
			global_position.y += (speed + scroll_speed) * delta
			global_position.x += sin(_t * 2.0) * 40.0 * delta
			rotation += delta * 0.8 if stats and stats.is_hazard else 0.0
		Pattern.BOSS:
			var target_y := 120.0
			if global_position.y < target_y:
				global_position.y += speed * delta
			else:
				global_position.x = _origin_x + sin(_t * 0.8) * 140.0
				global_position.x = clampf(global_position.x, 60.0, get_viewport_rect().size.x - 60.0)


func _try_fire(delta: float) -> void:
	if stats == null or stats.fire_interval <= 0.0 or projectile_pool == null:
		return
	if stats.is_hazard:
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = stats.fire_interval
	if stats.is_boss:
		_boss_fire()
	else:
		projectile_pool.spawn_enemy(global_position + Vector2(0, 16), Vector2(0, stats.projectile_speed), float(stats.contact_damage))
		AudioBus.play_enemy_shoot()


func _boss_fire() -> void:
	var ratio := hp / maxf(stats.max_hp, 1.0)
	_boss_phase = 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	var dirs: Array[Vector2] = [Vector2(0, 1)]
	match _boss_phase:
		1:
			dirs = [Vector2(-0.3, 1).normalized(), Vector2(0, 1), Vector2(0.3, 1).normalized()]
			_fire_timer = stats.fire_interval * 0.7
		2:
			dirs = []
			for i in 5:
				var a := -0.6 + i * 0.3
				dirs.append(Vector2(a, 1).normalized())
			_fire_timer = stats.fire_interval * 0.5
	for d in dirs:
		projectile_pool.spawn_enemy(global_position + Vector2(0, 24), d * stats.projectile_speed, float(stats.contact_damage))
	AudioBus.play_enemy_shoot()


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_poly.modulate = Color(2.0, 2.0, 2.0)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(self) and alive:
			_poly.modulate = Color.WHITE
	)
	if stats and stats.is_boss:
		EventBus.boss_hp_changed.emit(maxi(0.0, hp), stats.max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	var score := stats.score_value if stats else 50
	GameState.add_score(score)
	AudioBus.play_explode()
	EventBus.screen_shake.emit(3.0 if not (stats and stats.is_boss) else 12.0, 0.15)
	if stats and stats.is_boss:
		EventBus.boss_defeated.emit()
	# Chance to drop pickup (deferred — may die mid physics query)
	if not (stats and stats.is_hazard) and randf() < (0.35 if not (stats and stats.is_boss) else 1.0):
		call_deferred("_spawn_pickup")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")


func _spawn_pickup() -> void:
	if not is_inside_tree():
		return
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var p: Node = scene.instantiate()
	var parent := get_parent()
	if parent == null:
		return
	var pos := global_position
	parent.add_child(p)
	p.global_position = pos
	if p.has_method("setup"):
		var kinds := ["spread", "rapid", "shield", "heal"]
		p.setup(kinds[randi() % kinds.size()])


func _on_area_entered(area: Area2D) -> void:
	_contact(area)


func _on_body_entered(body: Node) -> void:
	_contact(body)


func _contact(target: Node) -> void:
	if not alive:
		return
	if target.is_in_group("player") and target.has_method("take_damage"):
		var dmg := stats.contact_damage if stats else 1
		target.take_damage(dmg)
		if stats and stats.is_hazard:
			take_damage(999.0)
		elif not (stats and stats.is_boss):
			take_damage(999.0)
