extends Area2D
## Base enemy / hazard with configurable movement patterns.

enum Pattern { DIVE, STRAFE, DRIFT, BOSS }

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
## Focused Laser Lv3 melt DoT (damage applied once per tick).
var _melt_ticks_left: int = 0
var _melt_dps: float = 0.0
var _melt_timer: float = 0.0
var _spark_cooldown: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _poly: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

const SPRITE_PATHS := {
	"scout": "res://assets/sprites/enemy_scout.png",
	"strafer": "res://assets/sprites/enemy_strafer.png",
	"drone": "res://assets/sprites/enemy_drone.png",
	"asteroid": "res://assets/sprites/enemy_asteroid.png",
	"boss": "res://assets/sprites/enemy_boss.png",
	"mid_boss": "res://assets/sprites/enemy_mid_boss.png",
}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(s: EnemyStats, pool: ProjectilePool, world_scroll: float, form_id: String = "") -> void:
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
	if s.is_boss and s.is_mid_boss:
		return SPRITE_PATHS["mid_boss"]
	if s.is_boss:
		return SPRITE_PATHS["boss"]
	var key := String(s.enemy_id)
	if SPRITE_PATHS.has(key):
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
	if global_position.y > vp.y + 80.0 and not (stats and stats.is_boss):
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


func _move(delta: float) -> void:
	var speed := stats.move_speed if stats else 120.0
	match pattern:
		Pattern.DIVE:
			# Mild sweep so popcorn reads as predictable arcs, not straight drops.
			global_position.y += (speed + scroll_speed) * delta
			global_position.x += sin(_t * 2.6 + _origin_x * 0.02) * 70.0 * delta
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
			_armor_angle += delta * 1.4
			var name_l := String(stats.display_name).to_lower() if stats else ""
			# Quantum Stalker: teleport periodically.
			if "stalker" in name_l or "quantum" in name_l:
				_teleport_cd -= delta
				if _teleport_cd <= 0.0:
					_teleport_cd = randf_range(3.4, 5.0)
					var vp2 := get_viewport_rect().size
					global_position = Vector2(randf_range(80.0, vp2.x - 80.0), randf_range(80.0, 200.0))
					_origin_x = global_position.x
					EventBus.gimmick_toast.emit("RELOCATING")
			var target_y := 120.0
			if "megalith" in name_l or "dreadnought" in name_l:
				target_y = 100.0
			if global_position.y < target_y:
				global_position.y += speed * delta
			else:
				var sway := 140.0
				if "platform" in name_l or "orbital" in name_l:
					sway = 100.0
				global_position.x = _origin_x + sin(_t * 0.8) * sway
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
		_fodder_fire()
		AudioBus.play_enemy_shoot()


func _fodder_fire() -> void:
	## Per-archetype fodder patterns so waves aren't one note.
	var muzzle := global_position + Vector2(0, 16)
	var spd := stats.projectile_speed
	var dmg := float(stats.contact_damage)
	var pat := String(stats.fire_pattern) if stats.fire_pattern != &"" else _default_fodder_pattern()
	match pat:
		"aimed":
			_fire_aimed(muzzle, spd, dmg, 1, 0.0)
		"side":
			var side := _strafe_dir if absf(_strafe_dir) > 0.1 else (1.0 if randf() > 0.5 else -1.0)
			_spawn_enemy_shot(muzzle, Vector2(side * 0.55, 1).normalized() * spd, dmg)
			_spawn_enemy_shot(muzzle, Vector2(0, 1) * spd * 0.95, dmg)
		"burst":
			_fire_spread_fan(muzzle, spd * 0.92, dmg, 3, 0.28)
			_fire_timer = stats.fire_interval * 1.15
		"spread":
			_fire_spread_fan(muzzle, spd, dmg, 3, 0.4)
		_:
			_spawn_enemy_shot(muzzle, Vector2(0, spd), dmg)


func _default_fodder_pattern() -> String:
	if stats == null:
		return "straight"
	match String(stats.enemy_id):
		"strafer":
			return "side"
		"drone":
			return "burst"
		_:
			return "straight"


func _boss_fire() -> void:
	var ratio := hp / maxf(stats.max_hp, 1.0)
	_boss_phase = 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	var name_l := String(stats.display_name).to_lower() if stats else ""
	var muzzle := global_position + Vector2(0, 24)
	var spd := stats.projectile_speed
	var dmg := float(stats.contact_damage)

	# Mid-bosses keep readable pressure with a light signature pattern.
	if stats.is_mid_boss:
		_mid_boss_fire(name_l, muzzle, spd, dmg)
		AudioBus.play_enemy_shoot()
		return

	# Stage bosses each teach a different reading skill.
	if "platform" in name_l or "orbital" in name_l:
		_fire_orbital_platform(muzzle, spd, dmg)
	elif "megalith" in name_l or "dreadnought" in name_l or "colossus" in name_l or "junkyard" in name_l:
		_fire_megalith(muzzle, spd, dmg)
	elif "leviathan" in name_l or "celestial" in name_l or "choir" in name_l or "null" in name_l:
		_fire_leviathan(muzzle, spd, dmg)
	elif "matrix" in name_l or "fabrication" in name_l or "kaleidoscope" in name_l or "array" in name_l:
		_fire_fabrication(muzzle, spd, dmg)
		if randf() < (0.14 + 0.08 * float(_boss_phase)):
			_spawn_fabricated_drone()
	elif "omega" in name_l or "dawn" in name_l or "tempest" in name_l or "dynamo" in name_l:
		_fire_omega(muzzle, spd, dmg)
	else:
		_fire_spread_fan(muzzle, spd, dmg, 1 + _boss_phase * 2, 0.55)
	AudioBus.play_enemy_shoot()


func _mid_boss_fire(name_l: String, muzzle: Vector2, spd: float, dmg: float) -> void:
	if "stalker" in name_l or "quantum" in name_l or "echo" in name_l or "revenant" in name_l:
		_fire_aimed(muzzle, spd * 1.05, dmg, 3 + _boss_phase, 0.18)
		_fire_timer = stats.fire_interval * (0.9 - 0.1 * float(_boss_phase))
	elif "drill" in name_l or "seismic" in name_l or "belt" in name_l or "tyrant" in name_l:
		_fire_spread_fan(muzzle, spd * 0.9, dmg, 3 + _boss_phase, 0.7)
		_fire_timer = stats.fire_interval * 0.95
	elif "overseer" in name_l or "prism" in name_l or "warden" in name_l:
		_fire_cross(muzzle, spd, dmg)
		if _boss_phase >= 1:
			_fire_spread_fan(muzzle, spd * 0.85, dmg, 3, 0.35)
		_fire_timer = stats.fire_interval * (0.9 - 0.08 * float(_boss_phase))
	elif "ace" in name_l or "twin" in name_l or "herald" in name_l or "solar" in name_l:
		_fire_aimed(muzzle, spd * 1.1, dmg, 2 + _boss_phase, 0.12)
		_fire_spread_fan(muzzle, spd, dmg, 3, 0.4)
		_fire_timer = stats.fire_interval * 0.85
	elif "storm" in name_l or "coil" in name_l:
		_fire_ring(muzzle, spd * 0.75, dmg, 6 + _boss_phase)
		_fire_aimed(muzzle, spd, dmg, 1 + _boss_phase, 0.1)
		_fire_timer = stats.fire_interval * 0.88
	else:
		_fire_spread_fan(muzzle, spd, dmg, 3 + _boss_phase, 0.5)
		_fire_timer = stats.fire_interval * (0.95 - 0.08 * float(_boss_phase))


func _fire_orbital_platform(muzzle: Vector2, spd: float, dmg: float) -> void:
	## Rotating armor boss: sweeping arcs that punish standing in one lane.
	var arms := 3 + _boss_phase
	var base := _armor_angle
	for i in arms:
		var a := base + TAU * float(i) / float(arms)
		var dir := Vector2(sin(a) * 0.85, 0.55 + 0.35 * absf(cos(a))).normalized()
		_spawn_enemy_shot(muzzle, dir * spd, dmg)
	if _boss_phase >= 1:
		_fire_aimed(muzzle, spd * 0.95, dmg, 1 + _boss_phase, 0.08)
	_fire_timer = stats.fire_interval * (0.9 - 0.12 * float(_boss_phase))


func _fire_megalith(muzzle: Vector2, spd: float, dmg: float) -> void:
	## Heavy wide volleys — slow, chunky, hard to squeeze through.
	var count := 5 + _boss_phase * 2
	_fire_spread_fan(muzzle, spd * 0.72, dmg, count, 0.95, {"scale": 1.35, "lifetime": 4.0})
	if _boss_phase >= 2 and int(_t * 2.0) % 2 == 0:
		# Occasional side sweep.
		for side in [-1.0, 1.0]:
			_spawn_enemy_shot(muzzle + Vector2(side * 40.0, 0), Vector2(side * 0.35, 1).normalized() * spd * 0.8, dmg, {"scale": 1.2})
	_fire_timer = stats.fire_interval * (1.05 - 0.1 * float(_boss_phase))


func _fire_leviathan(muzzle: Vector2, spd: float, dmg: float) -> void:
	## Ethereal wavy shots + faint "illusion" extras that drift oddly.
	var count := 4 + _boss_phase
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var a := lerpf(-0.55, 0.55, t)
		var dir := Vector2(a, 1).normalized()
		_spawn_enemy_shot(muzzle, dir * spd * 0.9, dmg, {
			"wave_amp": 18.0 + 8.0 * float(_boss_phase),
			"wave_freq": 6.0,
			"color": Color(0.85, 0.45, 1.0),
			"scale": 0.9,
		})
	# Illusions: slower, dimmer decoys that still hurt if ignored.
	var illusions := 2 + _boss_phase
	for i in illusions:
		var a2 := randf_range(-0.7, 0.7)
		_spawn_enemy_shot(muzzle + Vector2(randf_range(-30.0, 30.0), 0), Vector2(a2, 1).normalized() * spd * 0.55, dmg * 0.75, {
			"wave_amp": 28.0,
			"wave_freq": 4.5,
			"color": Color(0.7, 0.35, 0.95, 0.55),
			"scale": 0.7,
			"lifetime": 3.5,
		})
	_fire_timer = stats.fire_interval * (0.85 - 0.1 * float(_boss_phase))


func _fire_fabrication(muzzle: Vector2, spd: float, dmg: float) -> void:
	## Grid / cross denial while adds chew DPS.
	_fire_cross(muzzle, spd * 0.95, dmg)
	if _boss_phase >= 1:
		_fire_spread_fan(muzzle, spd, dmg, 3 + _boss_phase, 0.4)
	if _boss_phase >= 2:
		_fire_ring(muzzle, spd * 0.65, dmg, 8)
	_fire_timer = stats.fire_interval * (0.88 - 0.1 * float(_boss_phase))


func _fire_omega(muzzle: Vector2, spd: float, dmg: float) -> void:
	## Peak density: ring bursts + aimed stitch fire.
	var ring_n := 8 + _boss_phase * 2
	_fire_ring(muzzle, spd * 0.7, dmg, ring_n)
	_fire_aimed(muzzle, spd * 1.05, dmg, 2 + _boss_phase, 0.1)
	if _boss_phase >= 2:
		_fire_spread_fan(muzzle, spd * 0.85, dmg, 5, 0.55)
	_fire_timer = stats.fire_interval * (0.75 - 0.08 * float(_boss_phase))


func _fire_spread_fan(muzzle: Vector2, spd: float, dmg: float, count: int, width: float, opts: Dictionary = {}) -> void:
	count = maxi(count, 1)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var a := lerpf(-width, width, t)
		_spawn_enemy_shot(muzzle, Vector2(a, 1).normalized() * spd, dmg, opts)


func _fire_aimed(muzzle: Vector2, spd: float, dmg: float, count: int, spread: float, opts: Dictionary = {}) -> void:
	var aim := Vector2(0, 1)
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and is_instance_valid(player):
		aim = ((player as Node2D).global_position - muzzle).normalized()
		if aim.y < 0.2:
			aim.y = 0.2
			aim = aim.normalized()
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var angled := aim.rotated(lerpf(-spread, spread, t))
		_spawn_enemy_shot(muzzle, angled * spd, dmg, opts)


func _fire_cross(muzzle: Vector2, spd: float, dmg: float, opts: Dictionary = {}) -> void:
	for dir in [Vector2(0, 1), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.9, 0.35), Vector2(-0.9, 0.35)]:
		_spawn_enemy_shot(muzzle, dir.normalized() * spd, dmg, opts)


func _fire_ring(muzzle: Vector2, spd: float, dmg: float, count: int, opts: Dictionary = {}) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + _t * 0.4
		# Bias downward so portrait play stays fair.
		var dir := Vector2(sin(a), absf(cos(a)) * 0.35 + 0.65).normalized()
		_spawn_enemy_shot(muzzle, dir * spd, dmg, opts)


func _spawn_enemy_shot(muzzle: Vector2, velocity: Vector2, dmg: float, opts: Dictionary = {}) -> void:
	if projectile_pool == null:
		return
	projectile_pool.spawn_enemy(muzzle, velocity, dmg, opts)


func _spawn_fabricated_drone() -> void:
	var parent := get_parent()
	if parent == null or projectile_pool == null:
		return
	var scene: PackedScene = load("res://scenes/entities/enemy_base.tscn")
	var stats_drone: EnemyStats = load("res://resources/enemies/drone.tres")
	if scene == null or stats_drone == null:
		return
	var e: Node = scene.instantiate()
	parent.add_child(e)
	e.global_position = global_position + Vector2(randf_range(-60.0, 60.0), 40.0)
	if e.has_method("setup"):
		e.setup(stats_drone, projectile_pool, scroll_speed)


func take_damage(amount: float, armor_pierce: bool = false) -> void:
	if not alive:
		return
	# Orbital Defense Platform: rotating plating reduces frontal hits
	# unless the shot has armor pierce (Focused Laser Lv2+).
	if not armor_pierce and stats and stats.is_boss and not stats.is_mid_boss:
		var name_l := String(stats.display_name).to_lower()
		if "platform" in name_l or "orbital" in name_l:
			var facing := absf(sin(_armor_angle))
			if facing > 0.65:
				amount *= 0.55
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
	elif not (stats and stats.is_hazard) and randf() < (0.10 if not (stats and stats.is_boss) else 1.0):
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
	# Mid-boss: P-Chip + one rare defensive / utility drop.
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
		"option", "speed",
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