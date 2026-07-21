extends Area2D
## Pooled bullet used by both sides. Player shots can request extra behaviors
## via the opts Dictionary in activate():
##   pierce (int)          — pass through this many extra targets
##   homing (float)        — steering strength toward the nearest enemy
##   wave_amp (float)      — perpendicular sine oscillation amplitude (px)
##   wave_freq (float)     — oscillation speed
##   lifetime (float)      — seconds before despawn (default 3.0)
##   scale (float)         — visual/collision scale multiplier
##   color (Color)         — player-shot tint override
##   splash_radius (float) — AoE damage on hit (px)
##   splash_damage (float) — damage dealt to neighbors in splash radius
##   melt_ticks (int)      — apply melting DoT ticks to the hit target
##   melt_dps (float)      — damage per melt tick
##   cancel_bullets (bool) — destroy enemy projectiles this shot overlaps

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var from_player: bool = true
var pierce_left: int = 0
var homing: float = 0.0
var wave_amp: float = 0.0
var wave_freq: float = 8.0
var splash_radius: float = 0.0
var splash_damage: float = 0.0
var melt_ticks: int = 0
var melt_dps: float = 0.0
var cancel_bullets: bool = false
var armor_pierce: bool = false

var _active: bool = false
var _lifetime: float = 3.0
var _age: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _perp: Vector2 = Vector2.RIGHT
var _wave_phase: float = 0.0
var _hit_ids: Dictionary = {}
var _target: Node2D = null
var _retarget_timer: float = 0.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	deactivate()


func is_active() -> bool:
	return _active


func activate(pos: Vector2, vel: Vector2, dmg: float, player_shot: bool, opts: Dictionary = {}) -> void:
	global_position = pos
	_base_pos = pos
	velocity = vel
	damage = dmg
	from_player = player_shot
	_active = true
	_age = 0.0
	_wave_phase = 0.0
	_hit_ids.clear()
	_target = null
	_retarget_timer = 0.0
	pierce_left = int(opts.get("pierce", 0))
	homing = float(opts.get("homing", 0.0))
	wave_amp = float(opts.get("wave_amp", 0.0))
	wave_freq = float(opts.get("wave_freq", 8.0))
	_lifetime = float(opts.get("lifetime", 3.0))
	scale = Vector2.ONE * float(opts.get("scale", 1.0))
	splash_radius = float(opts.get("splash_radius", 0.0))
	splash_damage = float(opts.get("splash_damage", 0.0))
	melt_ticks = int(opts.get("melt_ticks", 0))
	melt_dps = float(opts.get("melt_dps", 0.0))
	cancel_bullets = bool(opts.get("cancel_bullets", false))
	armor_pierce = bool(opts.get("armor_pierce", false))
	if velocity.length() > 0.001:
		_perp = Vector2(-velocity.y, velocity.x).normalized()
		rotation = velocity.angle() + PI * 0.5
	visible = true
	set_process(true)
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if _collision:
		_collision.set_deferred("disabled", false)
	# Layers: 1=player, 2=player_proj, 3=enemy, 4=enemy_proj, 5=pickup, 6=hazard
	if from_player:
		collision_layer = 2
		# Also overlap enemy bullets when this shot can cancel them.
		collision_mask = 4 | 32 | (8 if cancel_bullets else 0)
		if _poly:
			_poly.color = opts.get("color", Color(0.55, 0.9, 1.0))
	else:
		collision_layer = 8
		# Hit player + hazards (asteroids block enemy fire).
		collision_mask = 1 | 32
		add_to_group("enemy_projectiles")
		if _poly:
			_poly.color = Color(1.0, 0.55, 0.35)


func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	velocity = Vector2.ZERO
	_target = null
	if is_in_group("enemy_projectiles"):
		remove_from_group("enemy_projectiles")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _collision:
		_collision.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if homing > 0.0:
		_steer_homing(delta)
	_base_pos += velocity * delta
	if wave_amp != 0.0:
		_wave_phase += delta * wave_freq
		global_position = _base_pos + _perp * sin(_wave_phase) * wave_amp
	else:
		global_position = _base_pos
	var vp := get_viewport_rect().size
	if _age > _lifetime or global_position.y < -60.0 or global_position.y > vp.y + 60.0 \
			or global_position.x < -60.0 or global_position.x > vp.x + 60.0:
		deactivate()


func _steer_homing(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not is_instance_valid(_target):
		_retarget_timer = 0.12
		_target = _nearest_enemy()
	if _target == null or not is_instance_valid(_target):
		return
	var speed := velocity.length()
	if speed < 0.001:
		return
	var desired := (_target.global_position - global_position).normalized() * speed
	velocity = velocity.lerp(desired, clampf(homing * delta, 0.0, 1.0))
	rotation = velocity.angle() + PI * 0.5


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var node := e as Node2D
		if node == null or node.get("alive") == false:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _apply_splash(center: Vector2, primary: Node) -> void:
	if splash_radius <= 0.0 or splash_damage <= 0.0:
		return
	var r2 := splash_radius * splash_radius
	var tree := get_tree()
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemies"):
		if e == null or e == primary or not is_instance_valid(e):
			continue
		if e.get("alive") == false:
			continue
		if not e.has_method("take_damage"):
			continue
		if e is Node2D and (e as Node2D).global_position.distance_squared_to(center) <= r2:
			e.take_damage(splash_damage)


func _try_hit(target: Node) -> void:
	if not _active:
		return
	if from_player:
		# Side-cancellation waves eat enemy bullets on contact.
		if cancel_bullets and target.is_in_group("enemy_projectiles"):
			if target.has_method("deactivate"):
				target.deactivate()
			elif target.has_method("queue_free"):
				target.queue_free()
			return
		if (target.is_in_group("enemies") or target.is_in_group("hazards")) and target.has_method("take_damage"):
			var id := target.get_instance_id()
			if _hit_ids.has(id):
				return
			_hit_ids[id] = true
			target.take_damage(damage, armor_pierce)
			if melt_ticks > 0 and melt_dps > 0.0 and target.has_method("apply_melt"):
				target.apply_melt(melt_ticks, melt_dps)
			_apply_splash(global_position, target)
			AudioBus.play_hit()
			if pierce_left > 0:
				pierce_left -= 1
			else:
				deactivate()
	else:
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(int(damage))
			deactivate()
		elif target.is_in_group("hazards"):
			# Rocks / barriers absorb enemy fire.
			deactivate()
			if target.has_method("absorb_bullet"):
				target.absorb_bullet(damage)
