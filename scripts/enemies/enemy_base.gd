extends Area2D
## Base enemy / hazard with configurable movement patterns.

enum Pattern { DIVE, STRAFE, DRIFT, BOSS, SPIRAL, WEAVE, ZIGZAG, ARC, HOVER_DART, LOOP, SWEEP, FIGURE8, PENDULUM, CHARGE, ORBIT, S_CURVE, JITTER, CHASE }

@export var stats: EnemyStats

var hp: float = 1.0
var pattern: Pattern = Pattern.DIVE
var scroll_speed: float = 40.0
var projectile_pool: ProjectilePool
var alive: bool = true
var formation_id: String = ""
var asteroid_tier: int = 0 ## 0=small 1=med 2=large

var _fire_timer: float = 0.0
var _strafe_dir: float = 1.0
var _t: float = 0.0
var _boss_phase: int = 0
var _origin_x: float = 0.0
var _teleport_cd: float = 0.0
var _armor_angle: float = 0.0
var _telegraph_lock: float = 0.0
var _spiral_angle: float = 0.0
var _zigzag_timer: float = 0.0
var _zigzag_target: float = 0.0
var _hover_timer: float = 0.0
var _hover_phase: int = 0
var _arc_phase: float = 0.0
var _flight_seed: float = 0.0
var _loop_state: int = 0
var _loop_t: float = 0.0
var _loop_center: Vector2 = Vector2.ZERO
var _loop_radius: float = 88.0
var _loop_dir: float = 1.0
var _loop_exit: Vector2 = Vector2.ZERO
var _loop_base_angle: float = 0.0
var _sweep_t: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_anchor: Vector2 = Vector2.ZERO
var _charge_timer: float = 0.0
var _charge_state: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _jitter_timer: float = 0.0
var _jitter_target: Vector2 = Vector2.ZERO
var _s_curve_phase: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _desired_vel: Vector2 = Vector2.ZERO
var _turn_rate: float = 12.0
var _prev_pos: Vector2 = Vector2.ZERO
## Focused Laser Lv3 melt DoT (damage applied once per tick).
var _melt_ticks_left: int = 0
var _melt_dps: float = 0.0
var _melt_timer: float = 0.0
var _spark_cooldown: float = 0.0

@onready var _sprite: Sprite2D = $SpriteHolder/Sprite2D
@onready var _holder: Node2D = $SpriteHolder
@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

const SPRITE_PATHS := {
	"scout": "res://assets/sprites/enemy_scout.svg",
	"strafer": "res://assets/sprites/enemy_strafer.svg",
	"drone": "res://assets/sprites/enemy_drone.svg",
	"asteroid": "res://assets/sprites/enemy_asteroid.svg",
	"boss": "res://assets/sprites/enemy_boss.svg",
	"mid_boss": "res://assets/sprites/enemy_mid_boss.svg",
	"dasher": "res://assets/sprites/enemy_dasher.svg",
	"weaver": "res://assets/sprites/enemy_weaver.svg",
	"heavy": "res://assets/sprites/enemy_heavy.svg",
	"bomber": "res://assets/sprites/enemy_bomber.svg",
	"support": "res://assets/sprites/enemy_support.svg",
	"sniper": "res://assets/sprites/enemy_sniper.svg",
	"swarmer": "res://assets/sprites/enemy_weaver.svg",
}
const BOSS_SPRITE_PATHS := {
	"kaleidoscope": "res://assets/sprites/enemy_boss_kaleidoscope.svg",
	"tempest": "res://assets/sprites/enemy_boss_tempest.svg",
	"choir": "res://assets/sprites/enemy_boss_choir.svg",
	"junkyard": "res://assets/sprites/enemy_boss_junkyard.svg",
	"dawn": "res://assets/sprites/enemy_boss_dawn.svg",
}
const MID_SPRITE_PATHS := {
	"transport": "res://assets/sprites/enemy_mid_transport.svg",
	"prism": "res://assets/sprites/enemy_mid_prism.svg",
	"coil": "res://assets/sprites/enemy_mid_coil.svg",
	"echo": "res://assets/sprites/enemy_mid_echo.svg",
	"tyrant": "res://assets/sprites/enemy_mid_tyrant.svg",
	"herald": "res://assets/sprites/enemy_mid_herald.svg",
}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(s: EnemyStats, pool: ProjectilePool, world_scroll: float, form_id: String = "", flight_override: StringName = &"") -> void:
	stats = s
	projectile_pool = pool
	scroll_speed = world_scroll
	formation_id = form_id
	hp = s.max_hp
	if s.is_hazard and String(s.enemy_id) == "asteroid":
		asteroid_tier = 2 if s.size.x >= 48.0 else (1 if s.size.x >= 30.0 else 0)
	_apply_visuals()
	_origin_x = global_position.x
	_fire_timer = s.fire_interval * 0.5
	if s.is_boss:
		pattern = Pattern.BOSS
		add_to_group("enemies")
		add_to_group("boss")
		if s.is_mid_boss:
			add_to_group("mid_boss")
		collision_layer = 4
		collision_mask = 2 | 1
		EventBus.boss_spawned.emit(self)
		EventBus.boss_hp_changed.emit(hp, stats.max_hp)
	elif s.is_hazard:
		pattern = Pattern.DRIFT
		add_to_group("hazards")
		collision_layer = 32
		collision_mask = 1 | 2 | 8
	else:
		var fp := String(flight_override) if flight_override != &"" else (String(s.flight_pattern) if s.flight_pattern != &"" else _default_flight_pattern())
		match fp:
			"spiral": pattern = Pattern.SPIRAL
			"weave": pattern = Pattern.WEAVE
			"zigzag": pattern = Pattern.ZIGZAG
			"arc": pattern = Pattern.ARC
			"hover_dart": pattern = Pattern.HOVER_DART
			"loop": pattern = Pattern.LOOP
			"sweep": pattern = Pattern.SWEEP
			"strafe": pattern = Pattern.STRAFE
			"drift": pattern = Pattern.DRIFT
			"figure8": pattern = Pattern.FIGURE8
			"pendulum": pattern = Pattern.PENDULUM
			"charge": pattern = Pattern.CHARGE
			"orbit": pattern = Pattern.ORBIT
			"s_curve": pattern = Pattern.S_CURVE
			"jitter": pattern = Pattern.JITTER
			"chase": pattern = Pattern.CHASE
			_: pattern = Pattern.DIVE
		add_to_group("enemies")
		collision_layer = 4
		collision_mask = 1 | 2
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	_flight_seed = randf() * TAU
	_spiral_angle = _flight_seed
	_vel = Vector2.ZERO
	_desired_vel = Vector2.ZERO
	_turn_rate = 12.0
	_zigzag_timer = randf_range(0.4, 1.0)
	_zigzag_target = (1.0 if _strafe_dir > 0 else -1.0) * randf_range(80.0, 130.0)
	_hover_timer = randf_range(0.8, 1.6)
	_arc_phase = randf_range(0.0, TAU)
	_loop_state = 0
	_loop_t = 0.0
	_loop_radius = randf_range(78.0, 118.0)
	_loop_dir = _strafe_dir
	_loop_center = Vector2.ZERO
	_loop_base_angle = 0.0
	_loop_exit = Vector2(_strafe_dir * randf_range(0.35, 0.75), 1.0).normalized()
	_sweep_t = 0.0
	_orbit_angle = _flight_seed
	_orbit_anchor = global_position + Vector2(0, 70)
	_charge_timer = randf_range(1.0, 2.2)
	_charge_state = 0
	_charge_dir = Vector2.DOWN
	_jitter_timer = 0.4
	_jitter_target = Vector2.ZERO
	_s_curve_phase = randf_range(0.0, TAU)
	_prev_pos = global_position
	if formation_id != "":
		var tracker := get_tree().get_first_node_in_group("formation_tracker")
		if tracker and tracker.has_method("register"):
			tracker.register(self, formation_id)


func _apply_visuals() -> void:
	if stats == null:
		return
	var path := _sprite_path_for(stats)
	var tex: Texture2D = load(path) if path != "" else null
	if _sprite and tex:
		_sprite.texture = tex
		_sprite.visible = true
		# Soft tint so mission variants keep identity without washing out art.
		_sprite.modulate = Color(
			clampf(0.55 + stats.color.r * 0.55, 0.4, 1.2),
			clampf(0.55 + stats.color.g * 0.55, 0.4, 1.2),
			clampf(0.55 + stats.color.b * 0.55, 0.4, 1.2),
			1.0
		)
		var target := maxf(stats.size.x, stats.size.y)
		var tex_size := maxf(tex.get_width(), tex.get_height())
		if tex_size > 0.0:
			var s := target / tex_size
			# Visual punch: fodder slightly oversized; bosses even more.
			if stats.is_boss:
				s *= 1.2 if stats.is_mid_boss else 1.4
			else:
				s *= 1.12
			_sprite.scale = Vector2(s, s)
		if _poly:
			_poly.visible = false
	elif _poly:
		_poly.visible = true
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
			"dasher":
				_poly.polygon = PackedVector2Array([
					Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x * 0.6, 0)
				])
			"weaver":
				_poly.polygon = PackedVector2Array([
					Vector2(0, -half.y), Vector2(half.x * 0.7, -half.y * 0.3),
					Vector2(half.x * 0.4, half.y), Vector2(-half.x * 0.4, half.y), Vector2(-half.x * 0.7, -half.y * 0.3)
				])
			"heavy":
				_poly.polygon = PackedVector2Array([
					Vector2(-half.x, -half.y * 0.7), Vector2(half.x, -half.y * 0.7),
					Vector2(half.x * 0.85, half.y * 0.7), Vector2(-half.x * 0.85, half.y * 0.7)
				])
			"bomber":
				_poly.polygon = PackedVector2Array([
					Vector2(-half.x * 0.8, -half.y * 0.5), Vector2(half.x * 0.8, -half.y * 0.5),
					Vector2(half.x, half.y * 0.6), Vector2(0, half.y), Vector2(-half.x, half.y * 0.6)
				])
			"support":
				_poly.polygon = PackedVector2Array([
					Vector2(0, -half.y), Vector2(half.x, -half.y * 0.4), Vector2(half.x, half.y * 0.4),
					Vector2(0, half.y), Vector2(-half.x, half.y * 0.4), Vector2(-half.x, -half.y * 0.4)
				])
			"sniper":
				_poly.polygon = PackedVector2Array([
					Vector2(0, -half.y), Vector2(half.x * 0.5, -half.y * 0.2), Vector2(half.x * 0.3, half.y), Vector2(-half.x * 0.3, half.y), Vector2(-half.x * 0.5, -half.y * 0.2)
				])
			"swarmer":
				_poly.polygon = PackedVector2Array([
					Vector2(0, -half.y * 0.9), Vector2(half.x * 0.9, half.y * 0.4), Vector2(0, half.y * 0.7), Vector2(-half.x * 0.9, half.y * 0.4)
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


func _sprite_path_for(s: EnemyStats) -> String:
	if s.is_boss:
		var arch := String(s.boss_archetype)
		if s.is_mid_boss:
			if MID_SPRITE_PATHS.has(arch) and FileAccess.file_exists(MID_SPRITE_PATHS[arch]):
				return MID_SPRITE_PATHS[arch]
			return SPRITE_PATHS["mid_boss"]
		if BOSS_SPRITE_PATHS.has(arch) and FileAccess.file_exists(BOSS_SPRITE_PATHS[arch]):
			return BOSS_SPRITE_PATHS[arch]
		return SPRITE_PATHS["boss"]
	var key := String(s.enemy_id)
	if SPRITE_PATHS.has(key) and FileAccess.file_exists(SPRITE_PATHS[key]):
		return SPRITE_PATHS[key]
	return SPRITE_PATHS["scout"]


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if _spark_cooldown > 0.0:
		_spark_cooldown -= delta
	_tick_melt(delta)
	_move(delta)
	_try_fire(delta)
	var vp := get_viewport_rect().size
	if (global_position.y > vp.y + 80.0 \
			or global_position.x < -80.0 \
			or global_position.x > vp.x + 80.0) \
			and not (stats and stats.is_boss):
		queue_free()


func apply_melt(ticks: int, dps: float) -> void:
	## Refresh melt so repeated laser hits keep the DoT rolling.
	_melt_ticks_left = maxi(_melt_ticks_left, ticks)
	_melt_dps = maxf(_melt_dps, dps)
	if _melt_timer <= 0.0:
		_melt_timer = 0.2


func _tick_melt(delta: float) -> void:
	if _melt_ticks_left <= 0:
		return
	_melt_timer -= delta
	if _melt_timer > 0.0:
		return
	_melt_timer = 0.2
	_melt_ticks_left -= 1
	take_damage(_melt_dps)
	if _melt_ticks_left <= 0:
		_melt_dps = 0.0


func _steer(delta: float, desired: Vector2) -> Vector2:
	_desired_vel = desired
	if _vel.length_squared() < 0.01:
		_vel = desired.normalized() * minf(desired.length(), 120.0)
	var rate := _turn_rate
	if pattern == Pattern.LOOP or pattern == Pattern.SWEEP:
		rate = 9.0
	elif pattern == Pattern.ZIGZAG or pattern == Pattern.HOVER_DART:
		rate = 10.0
	elif pattern == Pattern.ARC or pattern == Pattern.WEAVE:
		rate = 11.0
	elif pattern == Pattern.FIGURE8 or pattern == Pattern.ORBIT:
		rate = 9.5
	elif pattern == Pattern.CHARGE or pattern == Pattern.JITTER:
		rate = 14.0
	else:
		rate = 12.0
	var cur_ang := _vel.angle() if _vel.length_squared() > 1.0 else desired.angle()
	var des_ang := desired.angle()
	var ang_diff := wrapf(des_ang - cur_ang, -PI, PI)
	var max_step := rate * delta
	ang_diff = clampf(ang_diff, -max_step, max_step)
	var mag := lerpf(_vel.length(), desired.length(), clampf(delta * 4.0, 0.0, 1.0))
	_vel = Vector2.from_angle(cur_ang + ang_diff) * mag
	return _vel * delta


func _move(delta: float) -> void:
	var speed := stats.move_speed if stats else 120.0
	match pattern:
		Pattern.DIVE:
			var dive_desired := Vector2(sin(_t * 2.6 + _origin_x * 0.02) * 70.0, speed + scroll_speed)
			global_position += _steer(delta, dive_desired)
		Pattern.STRAFE:
			var strafe_desired := Vector2(_strafe_dir * speed, speed * 0.35 + scroll_speed)
			global_position += _steer(delta, strafe_desired)
			var vp := get_viewport_rect().size
			if global_position.x < 30.0 or global_position.x > vp.x - 30.0:
				_strafe_dir *= -1.0
				_desired_vel.x *= -1.0
				_vel.x *= -0.4
				global_position.x = clampf(global_position.x, 30.0, vp.x - 30.0)
		Pattern.DRIFT:
			var drift_desired := Vector2(sin(_t * 2.0) * 40.0, speed + scroll_speed)
			global_position += _steer(delta, drift_desired)
		Pattern.SPIRAL:
			_spiral_angle += delta * (2.2 if _strafe_dir > 0 else -2.2)
			var radius := 42.0 + 18.0 * sin(_t * 0.9 + _flight_seed)
			var spiral_desired := Vector2(cos(_spiral_angle) * radius * 1.8 + sin(_t * 1.4) * 18.0, speed * 0.7 + scroll_speed)
			global_position += _steer(delta, spiral_desired)
		Pattern.WEAVE:
			var w1 := sin(_t * 1.45 + _flight_seed) * 110.0
			var w2 := sin(_t * 2.9 + _flight_seed * 0.7) * 38.0
			var weave_desired := Vector2((w1 + w2) * 1.15, speed * 0.65 + scroll_speed)
			global_position += _steer(delta, weave_desired)
		Pattern.ZIGZAG:
			_zigzag_timer -= delta
			if _zigzag_timer <= 0.0:
				_zigzag_timer = randf_range(1.2, 2.0)
				_zigzag_target = clampf(
					global_position.x + _strafe_dir * randf_range(90.0, 180.0),
					38.0, get_viewport_rect().size.x - 38.0
				)
				_strafe_dir = -1.0 if _zigzag_target < global_position.x else 1.0
				if randf() < 0.12:
					_strafe_dir *= -1.0
					_zigzag_target = clampf(global_position.x + _strafe_dir * 110.0, 38.0, get_viewport_rect().size.x - 38.0)
			var dx := _zigzag_target - global_position.x
			var steer_x := clampf(dx * 1.2, -speed * 0.9, speed * 0.9)
			var zig_desired := Vector2(steer_x, speed * 0.8 + scroll_speed)
			global_position += _steer(delta, zig_desired)
		Pattern.ARC:
			_arc_phase += delta * 0.55
			var arc_r := 85.0 + 25.0 * sin(_t * 0.7 + _flight_seed)
			var arc_desired := Vector2(cos(_arc_phase) * arc_r * 1.1, speed * 0.75 + scroll_speed)
			global_position += _steer(delta, arc_desired)
		Pattern.HOVER_DART:
			_hover_timer -= delta
			if _hover_phase == 0:
				if _hover_timer <= 0.0:
					_hover_phase = 1
					_hover_timer = randf_range(0.45, 0.75)
					_zigzag_target = clampf(
						randf_range(50.0, get_viewport_rect().size.x - 50.0),
						40.0, get_viewport_rect().size.x - 40.0
					)
				var hover_desired := Vector2(sin(_t * 0.9 + _flight_seed) * 28.0, speed * 0.25 + scroll_speed * 0.55)
				global_position += _steer(delta, hover_desired)
			else:
				var hx := _zigzag_target - global_position.x
				var dart_desired := Vector2(clampf(hx * 1.2, -speed * 0.85, speed * 0.85), speed * 1.1 + scroll_speed)
				global_position += _steer(delta, dart_desired)
				if _hover_timer <= 0.0:
					_hover_phase = 0
					_hover_timer = randf_range(0.9, 1.6)
		Pattern.LOOP:
			_loop_move(delta, speed)
		Pattern.SWEEP:
			_sweep_move(delta, speed)
		Pattern.FIGURE8:
			var f8 := Vector2(sin(_t * 1.4 + _flight_seed) * 110.0, sin(_t * 2.8) * 28.0 + speed * 0.45 + scroll_speed)
			global_position += _steer(delta, f8)
		Pattern.PENDULUM:
			var pend := Vector2(sin(_t * 1.85 + _flight_seed) * 160.0, speed * 0.55 + scroll_speed)
			global_position += _steer(delta, pend)
		Pattern.CHARGE:
			_charge_timer -= delta
			if _charge_state == 0:
				var charge_hover := Vector2(sin(_t * 1.1 + _flight_seed) * 40.0, speed * 0.3 + scroll_speed * 0.5)
				global_position += _steer(delta, charge_hover)
				if _charge_timer <= 0.0:
					_charge_state = 1
					_charge_timer = 0.22
					var player := get_tree().get_first_node_in_group("player") as Node2D
					if player and is_instance_valid(player):
						_charge_dir = (player.global_position - global_position).normalized()
					else:
						_charge_dir = Vector2.DOWN
					if _charge_dir.y < 0.15:
						_charge_dir.y = 0.3
						_charge_dir = _charge_dir.normalized()
					EventBus.gimmick_toast.emit("CHARGE")
			elif _charge_state == 1:
				var dash := _charge_dir * (speed * 2.4 + scroll_speed * 0.4)
				global_position += _steer(delta, dash)
				if _charge_timer <= 0.0:
					_charge_state = 2
					_charge_timer = randf_range(1.2, 2.0)
			else:
				var recov := Vector2(sin(_t * 0.8) * 30.0, speed * 0.5 + scroll_speed)
				global_position += _steer(delta, recov)
				if _charge_timer <= 0.0:
					_charge_state = 0
					_charge_timer = randf_range(0.8, 1.6)
		Pattern.ORBIT:
			_orbit_angle += delta * (1.6 if _strafe_dir > 0 else -1.6)
			_orbit_anchor.y += (speed * 0.35 + scroll_speed) * delta
			var orbit_r := 52.0 + 12.0 * sin(_t * 0.7 + _flight_seed)
			var orbit_pos := _orbit_anchor + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_r
			var to_orbit := (orbit_pos - global_position) / maxf(delta, 0.001)
			var capped_orbit := to_orbit.normalized() * minf(to_orbit.length(), speed * 1.2)
			global_position += _steer(delta, capped_orbit)
		Pattern.S_CURVE:
			_s_curve_phase += delta * 0.9
			var lateral := sin(_s_curve_phase) * 95.0 * (1.2 + sin(_t * 0.6) * 0.3)
			var s_vel := Vector2(lateral, speed * 0.65 + scroll_speed)
			global_position += _steer(delta, s_vel)
		Pattern.JITTER:
			_jitter_timer -= delta
			if _jitter_timer <= 0.0:
				_jitter_timer = randf_range(0.22, 0.55)
				_jitter_target = Vector2(randf_range(-110.0, 110.0), randf_range(-20.0, 40.0))
			var jitt := _jitter_target + Vector2(0, speed * 0.6 + scroll_speed)
			global_position += _steer(delta, jitt)
		Pattern.CHASE:
			var chase_player := get_tree().get_first_node_in_group("player") as Node2D
			var chase_dir := Vector2.DOWN
			if chase_player and is_instance_valid(chase_player):
				chase_dir = (chase_player.global_position - global_position).normalized()
				if chase_dir.y < 0.2:
					chase_dir.y = 0.4
					chase_dir = chase_dir.normalized()
			var chase_v := chase_dir * speed + Vector2(0, scroll_speed * 0.6)
			global_position += _steer(delta, chase_v)
		Pattern.BOSS:
			_armor_angle += delta * 1.4
			BossPatterns.move(self, delta)
	if pattern == Pattern.DRIFT and stats and stats.is_hazard:
		rotation += delta * 0.8
		_prev_pos = global_position
	elif pattern == Pattern.BOSS:
		var boss_vel := (global_position - _prev_pos) / maxf(delta, 0.001)
		_prev_pos = global_position
		if boss_vel.length_squared() > 9.0:
			var heading := boss_vel.angle() + PI * 0.5
			rotation = lerp_angle(rotation, heading, clampf(delta * 5.0, 0.0, 1.0))
		var vx := boss_vel.x
		var bank_target := clampf(vx * 0.0025, -0.35, 0.35)
		if _holder:
			_holder.skew = lerp(_holder.skew, bank_target * 0.38, clampf(delta * 7.0, 0.0, 1.0))
			var squash_x := 1.0 - absf(bank_target) * 0.18
			var stretch_y := 1.0 + absf(bank_target) * 0.05
			_holder.scale.x = lerp(_holder.scale.x, squash_x, clampf(delta * 7.0, 0.0, 1.0))
			_holder.scale.y = lerp(_holder.scale.y, stretch_y, clampf(delta * 7.0, 0.0, 1.0))
		if _poly and _poly.visible:
			_poly.skew = lerp(_poly.skew, bank_target * 0.38, clampf(delta * 7.0, 0.0, 1.0))
			_poly.scale.x = lerp(_poly.scale.x, 1.0 - absf(bank_target) * 0.18, clampf(delta * 7.0, 0.0, 1.0))
	else:
		_prev_pos = global_position
		var heading := _vel.angle() + PI * 0.5 if _vel.length_squared() > 4.0 else rotation
		rotation = lerp_angle(rotation, heading, clampf(delta * _turn_rate * 1.6, 0.0, 1.0))
		var vx := _vel.x
		var bank_target := clampf(vx * 0.0040, -0.62, 0.62)
		if _holder:
			_holder.skew = lerp(_holder.skew, bank_target * 0.38, clampf(delta * 7.0, 0.0, 1.0))
			var squash_x := 1.0 - absf(bank_target) * 0.18
			var stretch_y := 1.0 + absf(bank_target) * 0.05
			_holder.scale.x = lerp(_holder.scale.x, squash_x, clampf(delta * 7.0, 0.0, 1.0))
			_holder.scale.y = lerp(_holder.scale.y, stretch_y, clampf(delta * 7.0, 0.0, 1.0))
		if _poly and _poly.visible:
			_poly.skew = lerp(_poly.skew, bank_target * 0.38, clampf(delta * 7.0, 0.0, 1.0))
			_poly.scale.x = lerp(_poly.scale.x, 1.0 - absf(bank_target) * 0.18, clampf(delta * 7.0, 0.0, 1.0))


func _loop_move(delta: float, speed: float) -> void:
	var vp := get_viewport_rect().size
	var entry_speed := speed * 1.65 + scroll_speed * 0.35
	var circle_speed := speed * 1.05
	var exit_speed := speed * 1.55 + scroll_speed * 0.85
	match _loop_state:
		0:
			var target := Vector2(vp.x * 0.5, vp.y * 0.42)
			var desired := (target - global_position).normalized() * entry_speed
			if desired.length_squared() < 1.0:
				desired = Vector2(-_loop_dir * 0.15, 1.0).normalized() * entry_speed
			global_position += _steer(delta, desired)
			if global_position.distance_to(target) < 26.0 or global_position.y >= target.y:
				_loop_state = 1
				_loop_t = 0.0
				_loop_center = target
				_loop_base_angle = (global_position - _loop_center).angle()
				_loop_exit = Vector2(-_loop_dir * randf_range(0.35, 0.75), 1.0).normalized()
		1:
			_loop_t += delta * (circle_speed / maxf(_loop_radius, 1.0))
			var ang := _loop_base_angle + _loop_t * _loop_dir
			var orbit_pos := _loop_center + Vector2(cos(ang), sin(ang)) * _loop_radius
			orbit_pos.y += entry_speed * 0.08 * delta * (_loop_t / TAU)
			var orbit_vel := (orbit_pos - global_position) / maxf(delta, 0.0001)
			var capped := orbit_vel.normalized() * minf(orbit_vel.length(), circle_speed * 1.4)
			global_position += _steer(delta, capped)
			if _loop_t >= TAU:
				_loop_state = 2
				_loop_t = 0.0
		2:
			global_position += _steer(delta, _loop_exit * exit_speed)


func _sweep_move(delta: float, speed: float) -> void:
	var vp := get_viewport_rect().size
	var entry_speed := speed * 1.75 + scroll_speed * 0.3
	var sweep_speed := speed * 1.45
	var exit_speed := speed * 1.6 + scroll_speed * 0.9
	match _loop_state:
		0:
			var target := Vector2(vp.x * 0.5, vp.y * 0.38)
			var desired := (target - global_position).normalized() * entry_speed
			if desired.length_squared() < 1.0:
				desired = Vector2(-_loop_dir * 0.4, 0.85).normalized() * entry_speed
			global_position += _steer(delta, desired)
			if global_position.distance_to(target) < 28.0 or global_position.y >= target.y:
				_loop_state = 1
				_sweep_t = global_position.x
				_loop_exit = Vector2(_loop_dir * randf_range(0.25, 0.55), 1.0).normalized()
		1:
			var sweep_desired := Vector2(_loop_dir * sweep_speed, speed * 0.18 + scroll_speed * 0.55)
			global_position += _steer(delta, sweep_desired)
			_sweep_t = global_position.x
			if (_loop_dir > 0.0 and global_position.x > vp.x - 34.0) \
					or (_loop_dir < 0.0 and global_position.x < 34.0):
				_loop_state = 2
		2:
			global_position += _steer(delta, _loop_exit * exit_speed)


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
		_fodder_fire()
		AudioBus.play_enemy_shoot()


func _fodder_fire() -> void:
	var muzzle := global_position + Vector2(0, 16)
	var spd := stats.projectile_speed
	var dmg := float(stats.contact_damage)
	var pat := String(stats.fire_pattern) if stats.fire_pattern != &"" else _default_fodder_pattern()
	match pat:
		"aimed":
			BossPatterns.aimed(self, muzzle, spd, dmg, 1, 0.0)
		"side":
			var side := _strafe_dir if absf(_strafe_dir) > 0.1 else (1.0 if randf() > 0.5 else -1.0)
			BossPatterns.spawn_shot(self, muzzle, Vector2(side * 0.55, 1).normalized() * spd, dmg)
			BossPatterns.spawn_shot(self, muzzle, Vector2(0, 1) * spd * 0.95, dmg)
		"burst":
			BossPatterns.spread_fan(self, muzzle, spd * 0.92, dmg, 2, 0.28)
			_fire_timer = stats.fire_interval * 1.15
		"spread":
			BossPatterns.spread_fan(self, muzzle, spd, dmg, 2, 0.34)
		"ring":
			BossPatterns.ring(self, muzzle, spd * 0.78, dmg, 5, {"scale": 0.82})
			_fire_timer = stats.fire_interval * 1.25
		"tri":
			BossPatterns.aimed(self, muzzle, spd, dmg, 2, 0.42)
		"cross":
			BossPatterns.cross(self, muzzle, spd * 0.88, dmg, {"scale": 0.9})
		"spiral":
			BossPatterns.spiral_shot(self, muzzle, spd, dmg, 1.35 if _strafe_dir > 0 else -1.35)
			if pattern == Pattern.SPIRAL and randf() < 0.35:
				BossPatterns.spiral_shot(self, muzzle, spd * 0.85, dmg, -1.35 if _strafe_dir > 0 else 1.35, {"scale": 0.85})
			_fire_timer = stats.fire_interval * 0.72
		"helix":
			BossPatterns.helix_pair(self, muzzle, spd, dmg)
			_fire_timer = stats.fire_interval * 0.95
		"arc":
			var dir := 1.0 if _strafe_dir > 0 else -1.0
			BossPatterns.arc_shot(self, muzzle, spd, dmg, dir * 1.15)
			if randf() < 0.4:
				BossPatterns.arc_shot(self, muzzle, spd * 0.92, dmg, -dir * 1.0, {"scale": 0.88})
		"weave":
			BossPatterns.spread_fan(self, muzzle, spd * 0.88, dmg, 2, 0.22)
		"snipe":
			BossPatterns.aimed(self, muzzle, spd * 1.25, dmg, 1, 0.06, {"scale": 1.15, "lifetime": 4.0})
			_fire_timer = stats.fire_interval * 1.35
		"shotgun":
			BossPatterns.spread_fan(self, muzzle, spd * 0.82, dmg, 5, 0.62)
			_fire_timer = stats.fire_interval * 1.45
		"double_aim":
			BossPatterns.aimed(self, muzzle, spd, dmg, 1, 0.0)
			BossPatterns.aimed(self, muzzle + Vector2(10, 0), spd * 0.92, dmg, 1, 0.0)
			_fire_timer = stats.fire_interval * 1.1
		"scatter":
			for k in 4:
				var rdir := Vector2(randf_range(-0.75, 0.75), 1).normalized()
				BossPatterns.spawn_shot(self, muzzle, rdir * spd * randf_range(0.75, 1.08), dmg, {"scale": randf_range(0.7, 1.0)})
			_fire_timer = stats.fire_interval * 1.25
		"mine":
			BossPatterns.spawn_shot(self, muzzle, Vector2(0, spd * 0.45), dmg, {"scale": 1.55, "lifetime": 4.8, "color": Color(1.0, 0.45, 0.2)})
			_fire_timer = stats.fire_interval * 1.5
		"laser_line":
			BossPatterns.aimed(self, muzzle, spd * 1.35, dmg, 3, 0.05, {"scale": 0.72, "lifetime": 3.2})
			_fire_timer = stats.fire_interval * 1.2
		"boomerang":
			var bdir := 1.0 if _strafe_dir > 0 else -1.0
			BossPatterns.arc_shot(self, muzzle, spd * 0.88, dmg, bdir * 1.35, {"scale": 0.95, "lifetime": 3.4})
			BossPatterns.arc_shot(self, muzzle, spd * 0.88, dmg, -bdir * 1.35, {"scale": 0.95, "lifetime": 3.4})
		"volley":
			BossPatterns.spread_fan(self, muzzle, spd, dmg, 3, 0.42)
			get_tree().create_timer(0.14).timeout.connect(func() -> void:
				if is_instance_valid(self) and alive and projectile_pool != null:
					BossPatterns.spread_fan(self, muzzle, spd * 0.92, dmg, 3, 0.42, {"scale": 0.92})
			)
			_fire_timer = stats.fire_interval * 1.55
		"split":
			# New: forward + perpendicular split — distinct from scatter/burst
			BossPatterns.spawn_shot(self, muzzle, Vector2(0, 1) * spd, dmg, {"scale": 0.95})
			BossPatterns.spawn_shot(self, muzzle, Vector2(0.85, 0.55).normalized() * spd * 0.92, dmg, {"scale": 0.85})
			BossPatterns.spawn_shot(self, muzzle, Vector2(-0.85, 0.55).normalized() * spd * 0.92, dmg, {"scale": 0.85})
			_fire_timer = stats.fire_interval * 1.1
		_:
			BossPatterns.spawn_shot(self, muzzle, Vector2(0, spd), dmg)


func _side_spawn_setup() -> void:
	if pattern != Pattern.LOOP and pattern != Pattern.SWEEP:
		return
	var vp := get_viewport_rect().size
	var side := 1.0 if _loop_dir > 0 else -1.0
	var edge_x := -24.0 if side < 0 else vp.x + 24.0
	global_position.x = edge_x + side * randf_range(10.0, 26.0)
	global_position.y = vp.y * 0.22 + randf_range(-28.0, 28.0)


func _default_flight_pattern() -> String:
	if stats == null:
		return "dive"
	match String(stats.enemy_id):
		"strafer":
			var strafer_picks := ["zigzag", "weave", "pendulum", "s_curve"]
			return strafer_picks[randi() % strafer_picks.size()]
		"drone":
			var drone_picks := ["spiral", "hover_dart", "orbit", "jitter"]
			return drone_picks[randi() % drone_picks.size()]
		"dasher":
			return "charge" if randf() < 0.6 else "figure8"
		"weaver":
			var weaver_picks := ["figure8", "s_curve", "pendulum"]
			return weaver_picks[randi() % weaver_picks.size()]
		"heavy":
			return "orbit" if randf() < 0.5 else "jitter"
		"bomber":
			return "drift" if randf() < 0.5 else "jitter"
		"support":
			return "hover_dart" if randf() < 0.5 else "orbit"
		"sniper":
			return "hover_dart" if randf() < 0.6 else "jitter"
		"swarmer":
			var swarm_picks := ["dive", "arc", "chase", "s_curve"]
			return swarm_picks[randi() % swarm_picks.size()]
		_:
			var scout_picks := ["dive", "arc", "weave", "s_curve", "chase"]
			return scout_picks[randi() % scout_picks.size()]

func _default_fodder_pattern() -> String:
	if stats == null:
		return "straight"
	match String(stats.enemy_id):
		"strafer":
			return "helix" if pattern == Pattern.WEAVE else ("arc" if pattern == Pattern.ZIGZAG else "side")
		"drone":
			return "spiral" if pattern == Pattern.SPIRAL else ("helix" if pattern == Pattern.HOVER_DART else "arc")
		"dasher":
			return "shotgun" if randf() < 0.6 else "spread"
		"weaver":
			var weaver_r := randf()
			if weaver_r < 0.4:
				return "split"
			return "scatter" if weaver_r < 0.7 else "weave"
		"heavy":
			return "shotgun" if randf() < 0.5 else "volley"
		"bomber":
			return "mine" if randf() < 0.6 else "scatter"
		"support":
			return "helix" if randf() < 0.5 else "cross"
		"sniper":
			return "snipe"
		"swarmer":
			var swarm_r := randf()
			if swarm_r < 0.35:
				return "split"
			return "spread" if swarm_r < 0.65 else "scatter"
		_:
			var scout_picks := ["straight", "burst", "scatter", "side"]
			return scout_picks[randi() % scout_picks.size()]


func _boss_fire() -> void:
	## Phase + archetype dispatch live in BossPatterns (scripts/enemies/boss_patterns.gd).
	var ratio := hp / maxf(stats.max_hp, 1.0)
	_boss_phase = 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	BossPatterns.fire(self)


func take_damage(amount: float, armor_pierce: bool = false) -> void:
	if not alive:
		return
	# Orbital Defense Platform: rotating plating reduces frontal hits
	# unless the shot has armor pierce (Focused Laser Lv2+).
	if not armor_pierce and stats and stats.is_boss and not stats.is_mid_boss:
		var mult: float = BossPatterns.armor_mult(stats, _armor_angle)
		if mult < 1.0:
			amount *= mult
			EventBus.gimmick_toast.emit("ARMORED")
	hp -= amount
	_flash_hit()
	if amount >= 0.75 and _spark_cooldown <= 0.0 and get_parent():
		_spark_cooldown = 0.045
		var spark_col := Color(1.0, 0.95, 0.75)
		if stats:
			spark_col = stats.color.lightened(0.45)
		CombatFX.spawn_hit_spark(get_parent(), global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0)), spark_col)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(self) and alive:
			_clear_flash()
	)
	if stats and stats.is_boss:
		EventBus.boss_hp_changed.emit(maxi(0.0, hp), stats.max_hp)
	if hp <= 0.0:
		_die()


func _flash_hit() -> void:
	if GameState.reduce_flashes:
		return
	if _sprite and _sprite.visible:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
	if _poly:
		_poly.modulate = Color(2.0, 2.0, 2.0)


func _clear_flash() -> void:
	if _sprite and _sprite.visible and stats:
		_sprite.modulate = Color(
			clampf(0.55 + stats.color.r * 0.55, 0.4, 1.2),
			clampf(0.55 + stats.color.g * 0.55, 0.4, 1.2),
			clampf(0.55 + stats.color.b * 0.55, 0.4, 1.2),
			1.0
		)
	if _poly:
		_poly.modulate = Color.WHITE


func absorb_bullet(amount: float = 1.0) -> void:
	## Enemy bullets blocked by this hazard still chip large rocks.
	if stats and stats.is_hazard and asteroid_tier >= 1:
		take_damage(amount * 0.35)


func _die() -> void:
	alive = false
	var score := stats.score_value if stats else 50
	GameState.add_score(score)
	AudioBus.play_explode()
	var is_boss := stats != null and stats.is_boss
	EventBus.screen_shake.emit(3.0 if not is_boss else 12.0, 0.15)
	if is_boss:
		# Brief freeze frame so boss takedowns land with real weight.
		EventBus.hitstop_requested.emit(0.16 if not (stats and stats.is_mid_boss) else 0.09)
	var fx_parent := get_parent()
	if fx_parent:
		var col := stats.color if stats else Color(1.0, 0.65, 0.3)
		if is_boss:
			CombatFX.spawn_ring(fx_parent, global_position, col.lightened(0.25), 22.0)
			CombatFX.spawn_burst(fx_parent, global_position, col.lightened(0.15), 18, 42.0)
			CombatFX.spawn_burst(fx_parent, global_position + Vector2(randf_range(-12.0, 12.0), -8.0), Color(1.0, 0.85, 0.4), 12, 28.0)
		else:
			CombatFX.spawn_burst(fx_parent, global_position, col.lightened(0.2), 8 if not (stats and stats.is_hazard) else 6, 22.0)
	EventBus.enemy_killed.emit(
		stats != null and stats.is_hazard,
		is_boss
	)
	if formation_id != "":
		var tracker := get_tree().get_first_node_in_group("formation_tracker")
		if tracker and tracker.has_method("notify_killed"):
			tracker.notify_killed(self, formation_id)
	if stats and stats.is_boss:
		EventBus.boss_defeated.emit()
	if stats and stats.is_hazard and String(stats.enemy_id) == "asteroid" and asteroid_tier >= 1:
		call_deferred("_split_asteroid")
	if stats and stats.is_mid_boss:
		call_deferred("_spawn_major_reward")
	else:
		var is_asteroid := stats != null and String(stats.enemy_id) == "asteroid"
		var drop_chance := 1.0 if (stats and stats.is_boss) else 0.05
		if is_asteroid:
			drop_chance = 0.22 if asteroid_tier == 2 else (0.14 if asteroid_tier == 1 else 0.08)
		if (is_asteroid or not (stats and stats.is_hazard)) and randf() < drop_chance:
			call_deferred("_spawn_pickup")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# Kill-flash: white pop + scale-out before the body disappears.
	set_physics_process(false)
	var vis: CanvasItem = _sprite if _sprite and _sprite.visible else _poly
	if vis and not GameState.reduce_flashes:
		vis.modulate = Color(3.0, 3.0, 3.0, 1.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(vis, "scale", vis.scale * 1.35, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(vis, "modulate:a", 0.0, 0.13)
		await tw.finished
	queue_free()


func _split_asteroid() -> void:
	if not is_inside_tree() or stats == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var child_tier := asteroid_tier - 1
	var scale := 0.55 if child_tier == 1 else 0.5
	for i in 2:
		var child_stats := stats.duplicate() as EnemyStats
		child_stats.max_hp = maxf(1.0, stats.max_hp * 0.45)
		child_stats.size = stats.size * scale
		child_stats.move_speed = stats.move_speed * (1.25 if child_tier == 0 else 1.1)
		child_stats.score_value = maxi(25, int(stats.score_value * 0.4))
		child_stats.is_hazard = true
		child_stats.enemy_id = &"asteroid"
		var scene: PackedScene = load("res://scenes/entities/enemy_base.tscn")
		if scene == null:
			continue
		var e: Node = scene.instantiate()
		parent.add_child(e)
		e.global_position = global_position + Vector2((-1.0 if i == 0 else 1.0) * 18.0, -8.0)
		if e.has_method("setup"):
			e.setup(child_stats, projectile_pool, scroll_speed)
			e.asteroid_tier = child_tier


func _spawn_major_reward() -> void:
	# Mid-boss: Power pickup + one rare defensive / utility drop.
	_spawn_pickup_at(global_position + Vector2(-28, 0), "power")
	_spawn_pickup_at(global_position + Vector2(28, 0), _rare_utility_kind())


func _rare_utility_kind() -> String:
	var rares := ["shield", "bomb", "energy", "heal"]
	return rares[randi() % rares.size()]


func _spawn_pickup() -> void:
	if not is_inside_tree():
		return
	# Common fodder: color weapons + stackables. Rare utilities never drop here.
	var kinds := [
		"spread", "laser", "homing",
		"power", "power",
		"drone",
	]
	_spawn_pickup_at(global_position, kinds[randi() % kinds.size()])


func _spawn_pickup_at(pos: Vector2, kind: String) -> void:
	if not is_inside_tree():
		return
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var p: Node = scene.instantiate()
	parent.add_child(p)
	p.global_position = pos
	if p.has_method("setup"):
		p.setup(kind)

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