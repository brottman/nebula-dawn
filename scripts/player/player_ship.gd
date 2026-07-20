extends CharacterBody2D
## Player strike craft — touch-drag or 8-way move, auto-fire, power-ups.

const PLAYFIELD_MARGIN := 24.0
## Keep the ship above the finger so the craft stays visible.
const TOUCH_OFFSET := Vector2(0, -56)
const TOUCH_FOLLOW := 22.0

@export var move_speed: float = 280.0
@export var max_hp: int = 5
@export var fire_cooldown: float = 0.18
@export var bullet_speed: float = 520.0
@export var bullet_damage: float = 1.0

var hp: int = 5
var invuln_time: float = 0.0
var shield_time: float = 0.0
var rapid_time: float = 0.0
var spread_time: float = 0.0
var _fire_timer: float = 0.0
var _flash_timer: float = 0.0
var dead: bool = false

var projectile_pool: ProjectilePool

var _touch_active: bool = false
var _touch_index: int = -1
var _touch_world: Vector2 = Vector2.ZERO

@onready var _poly: Polygon2D = $Polygon2D
@onready var _shield_visual: Polygon2D = $ShieldVisual
@onready var _engine: GPUParticles2D = $EngineParticles


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	_shield_visual.visible = false
	EventBus.player_hp_changed.emit(hp, max_hp)


func setup(pool: ProjectilePool) -> void:
	projectile_pool = pool


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_active = true
			_touch_index = touch.index
			_touch_world = _screen_to_world(touch.position)
			get_viewport().set_input_as_handled()
		elif touch.index == _touch_index:
			_touch_active = false
			_touch_index = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_active and drag.index == _touch_index:
			_touch_world = _screen_to_world(drag.position)
			get_viewport().set_input_as_handled()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_timers(delta)
	_handle_movement(delta)
	_handle_fire(delta)
	_update_visuals(delta)


func _update_timers(delta: float) -> void:
	if invuln_time > 0.0:
		invuln_time -= delta
	if shield_time > 0.0:
		shield_time -= delta
		_shield_visual.visible = shield_time > 0.0
	else:
		_shield_visual.visible = false
	if rapid_time > 0.0:
		rapid_time -= delta
	if spread_time > 0.0:
		spread_time -= delta
	if _flash_timer > 0.0:
		_flash_timer -= delta


func _handle_movement(delta: float) -> void:
	var vp := get_viewport_rect().size
	if _touch_active:
		var target := _touch_world + TOUCH_OFFSET
		global_position = global_position.lerp(target, 1.0 - exp(-TOUCH_FOLLOW * delta))
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * move_speed
		move_and_slide()
	global_position.x = clampf(global_position.x, PLAYFIELD_MARGIN, vp.x - PLAYFIELD_MARGIN)
	global_position.y = clampf(global_position.y, PLAYFIELD_MARGIN, vp.y - PLAYFIELD_MARGIN)


func _handle_fire(delta: float) -> void:
	_fire_timer -= delta
	# Auto-fire; hold also works (same path)
	var cd := fire_cooldown * (0.45 if rapid_time > 0.0 else 1.0)
	if _fire_timer > 0.0:
		return
	_fire_timer = cd
	_shoot()


func _shoot() -> void:
	if projectile_pool == null:
		return
	var origin := global_position + Vector2(0, -18)
	var shots: Array[Vector2] = [Vector2(0, -1)]
	if spread_time > 0.0:
		shots = [Vector2(-0.35, -1).normalized(), Vector2(0, -1), Vector2(0.35, -1).normalized()]
	for dir in shots:
		projectile_pool.spawn_player(origin, dir * bullet_speed, bullet_damage)
	AudioBus.play_shoot()


func take_damage(amount: int) -> void:
	if dead or invuln_time > 0.0:
		return
	if shield_time > 0.0:
		shield_time = 0.0
		_shield_visual.visible = false
		invuln_time = 0.6
		AudioBus.play_player_hurt()
		EventBus.screen_shake.emit(4.0, 0.12)
		return
	hp = maxi(0, hp - amount)
	invuln_time = 1.0
	_flash_timer = 0.2
	AudioBus.play_player_hurt()
	EventBus.screen_shake.emit(8.0, 0.18)
	EventBus.player_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	_touch_active = false
	_touch_index = -1
	visible = false
	set_physics_process(false)
	AudioBus.play_explode()
	EventBus.player_died.emit()


func apply_pickup(kind: String) -> void:
	match kind:
		"spread":
			spread_time = 8.0
		"rapid":
			rapid_time = 8.0
		"shield":
			shield_time = 6.0
			_shield_visual.visible = true
		"heal":
			hp = mini(max_hp, hp + 1)
			EventBus.player_hp_changed.emit(hp, max_hp)
	AudioBus.play_pickup()
	EventBus.pickup_collected.emit(kind)


func _update_visuals(_delta: float) -> void:
	if invuln_time > 0.0:
		_poly.modulate.a = 0.35 if int(Time.get_ticks_msec() / 60) % 2 == 0 else 1.0
	else:
		_poly.modulate.a = 1.0
	if _flash_timer > 0.0:
		_poly.color = Color(1.0, 1.0, 1.0)
	else:
		_poly.color = Color(0.43, 0.78, 1.0)
	if _engine:
		_engine.emitting = not dead
