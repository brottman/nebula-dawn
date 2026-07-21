extends CharacterBody2D
## Player strike craft — touch-drag or 8-way move, auto-fire, power-ups.
## Picked-up weapons persist until the ship takes hull damage; POWER pickups
## raise the current weapon's level (max MAX_WEAPON_LEVEL) — even the blaster.

const PLAYFIELD_MARGIN := 24.0
## Keep the ship above the finger so the craft stays visible.
const TOUCH_OFFSET := Vector2(0, -56)
const TOUCH_FOLLOW := 22.0
## Highest power level any weapon (including the blaster) can reach.
const MAX_WEAPON_LEVEL := 3

enum Weapon { BLASTER, SPREAD, RAILGUN, HOMING, WAVE, FLAK }

const WEAPON_NAMES := {
	Weapon.BLASTER: "BLASTER",
	Weapon.SPREAD: "SPREAD",
	Weapon.RAILGUN: "RAILGUN",
	Weapon.HOMING: "HOMING",
	Weapon.WAVE: "WAVE",
	Weapon.FLAK: "FLAK",
}
const WEAPON_COOLDOWNS := {
	Weapon.BLASTER: 0.18,
	Weapon.SPREAD: 0.24,
	Weapon.RAILGUN: 0.55,
	Weapon.HOMING: 0.40,
	Weapon.WAVE: 0.30,
	Weapon.FLAK: 0.50,
}

@export var move_speed: float = 280.0
@export var max_hp: int = 5
@export var fire_cooldown: float = 0.18
@export var bullet_speed: float = 520.0
@export var bullet_damage: float = 1.0

var hp: int = 5
var invuln_time: float = 0.0
var shield_time: float = 0.0
var rapid_time: float = 0.0
var weapon: int = Weapon.BLASTER
var weapon_level: int = 1
var _fire_timer: float = 0.0
var _flash_timer: float = 0.0
var dead: bool = false

## Stage 3 plasma: +50% damage, secondaries disabled.
var plasma_active: bool = false
var damage_mult: float = 1.0
var secondaries_disabled: bool = false

## Stage 5 overdrive (filled by grazing singularities).
var overdrive: float = 0.0
const OVERDRIVE_MAX := 100.0
var overdrive_time: float = 0.0

var projectile_pool: ProjectilePool

var _touch_active: bool = false
var _touch_index: int = -1
var _touch_world: Vector2 = Vector2.ZERO
var _cinematic: bool = false

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
	if dead or _cinematic:
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
	if dead or _cinematic:
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
	if _flash_timer > 0.0:
		_flash_timer -= delta
	if overdrive_time > 0.0:
		overdrive_time -= delta
		if overdrive_time <= 0.0:
			Engine.time_scale = 1.0
			EventBus.gimmick_toast.emit("OVERDRIVE END")


func enter_plasma() -> void:
	plasma_active = true
	damage_mult = 1.5
	secondaries_disabled = true
	EventBus.gimmick_toast.emit("PLASMA BOOST")


func exit_plasma() -> void:
	plasma_active = false
	damage_mult = 1.0
	secondaries_disabled = false


func clear_zone_effects() -> void:
	exit_plasma()
	overdrive_time = 0.0
	Engine.time_scale = 1.0


func add_overdrive(amount: float) -> void:
	if overdrive_time > 0.0:
		return
	overdrive = minf(OVERDRIVE_MAX, overdrive + amount)
	EventBus.overdrive_changed.emit(overdrive, OVERDRIVE_MAX)
	if overdrive >= OVERDRIVE_MAX:
		_activate_overdrive()


func _activate_overdrive() -> void:
	overdrive = 0.0
	EventBus.overdrive_changed.emit(overdrive, OVERDRIVE_MAX)
	overdrive_time = 1.6
	Engine.time_scale = 0.4
	rapid_time = maxf(rapid_time, 1.6)
	EventBus.overdrive_activated.emit()
	EventBus.gimmick_toast.emit("OVERDRIVE")


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
	if _fire_timer > 0.0:
		return
	var cd: float = WEAPON_COOLDOWNS.get(weapon, fire_cooldown)
	cd *= 0.45 if rapid_time > 0.0 else 1.0
	_fire_timer = cd
	_shoot()


func _set_weapon(w: int) -> void:
	weapon = w
	weapon_level = 1
	_emit_weapon_changed()


func _power_up() -> void:
	if weapon_level >= MAX_WEAPON_LEVEL:
		# Already maxed — convert the pickup into score instead.
		GameState.add_score(100)
		return
	weapon_level += 1
	_emit_weapon_changed()


## Losing hull integrity knocks the ship back to the stock blaster.
func _reset_weapon() -> void:
	if weapon == Weapon.BLASTER and weapon_level == 1:
		return
	weapon = Weapon.BLASTER
	weapon_level = 1
	EventBus.weapon_changed.emit("")


func _emit_weapon_changed() -> void:
	if weapon == Weapon.BLASTER and weapon_level == 1:
		EventBus.weapon_changed.emit("")
		return
	var text: String = WEAPON_NAMES[weapon]
	if weapon_level > 1:
		text += " Lv%d" % weapon_level
	EventBus.weapon_changed.emit(text)


func _shoot() -> void:
	if projectile_pool == null:
		return
	var origin := global_position + Vector2(0, -18)
	var dmg := bullet_damage * damage_mult
	var active_weapon := weapon
	if secondaries_disabled and weapon != Weapon.BLASTER:
		active_weapon = Weapon.BLASTER
	match active_weapon:
		Weapon.SPREAD:
			var count := 3 + weapon_level * 2
			for i in count:
				var dir := Vector2(-0.7 + 1.4 * i / float(count - 1), -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * bullet_speed, dmg)
			AudioBus.play_shoot(720.0)
		Weapon.RAILGUN:
			projectile_pool.spawn_player(origin, Vector2(0, -900.0), (2.0 + 2.0 * weapon_level) * damage_mult, {
				"pierce": 99, "scale": 1.5 + 0.3 * weapon_level, "color": Color(0.8, 1.0, 1.0)})
			AudioBus.play_shoot(1250.0)
		Weapon.HOMING:
			var count := 1 + weapon_level
			for i in count:
				var dir := Vector2((i - (count - 1) * 0.5) * 0.3, -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * 380.0, (1.0 + 0.5 * weapon_level) * damage_mult, {
					"homing": 7.0, "scale": 1.1, "color": Color(1.0, 0.75, 0.3)})
			AudioBus.play_shoot(600.0)
		Weapon.WAVE:
			for side in [-1.0, 1.0]:
				projectile_pool.spawn_player(origin + Vector2(side * 10.0, 0.0), Vector2(0, -340.0), (1.0 + weapon_level) * damage_mult, {
					"wave_amp": side * 55.0, "wave_freq": 9.0, "pierce": weapon_level,
					"scale": 1.4, "color": Color(0.85, 0.5, 1.0)})
			AudioBus.play_shoot(500.0)
		Weapon.FLAK:
			var count := 4 + weapon_level * 2
			for i in count:
				var dir := Vector2(randf_range(-0.55, 0.55), -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * randf_range(480.0, 640.0), dmg, {
					"lifetime": 0.3 + 0.1 * weapon_level, "scale": 0.8, "color": Color(1.0, 0.5, 0.4)})
			AudioBus.play_shoot(300.0)
		_:
			for i in weapon_level:
				var offset := (i - (weapon_level - 1) * 0.5) * 12.0
				projectile_pool.spawn_player(origin + Vector2(offset, 0.0), Vector2(0, -bullet_speed), dmg)
			AudioBus.play_shoot()


func take_damage(amount: int) -> void:
	if dead or _cinematic or invuln_time > 0.0:
		return
	if shield_time > 0.0:
		shield_time = 0.0
		_shield_visual.visible = false
		invuln_time = 0.6
		AudioBus.play_player_hurt()
		EventBus.screen_shake.emit(4.0, 0.12)
		return
	hp = maxi(0, hp - amount)
	_reset_weapon()
	invuln_time = 1.0
	_flash_timer = 0.2
	AudioBus.play_player_hurt()
	EventBus.screen_shake.emit(8.0, 0.18)
	EventBus.player_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	_cinematic = false
	_touch_active = false
	_touch_index = -1
	clear_zone_effects()
	visible = false
	set_physics_process(false)
	AudioBus.play_explode()
	EventBus.player_died.emit()


## Victory outro: drift to screen center, hover, then streak off the top.
func play_victory_exit() -> void:
	if dead or not is_inside_tree():
		return
	_cinematic = true
	_touch_active = false
	_touch_index = -1
	invuln_time = 999.0
	velocity = Vector2.ZERO
	clear_zone_effects()
	if _engine:
		_engine.emitting = true
	_poly.modulate.a = 1.0
	_poly.color = Color(0.43, 0.78, 1.0)

	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.48)
	var offscreen := Vector2(vp.x * 0.5, -120.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Glide to center.
	tween.tween_property(self, "global_position", center, 1.15)
	# Soft hover bob.
	tween.tween_property(self, "global_position", center + Vector2(0, -10), 0.35)
	tween.tween_property(self, "global_position", center + Vector2(0, 8), 0.35)
	tween.tween_property(self, "global_position", center, 0.3)
	# Brief hold, then accelerate off the top with a slight stretch.
	tween.tween_interval(0.35)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", offscreen, 0.75)
	tween.parallel().tween_property(self, "scale", Vector2(0.7, 1.45), 0.75)
	tween.parallel().tween_property(_poly, "modulate:a", 0.0, 0.55).set_delay(0.2)
	await tween.finished
	visible = false


func apply_pickup(kind: String) -> void:
	match kind:
		"spread":
			_set_weapon(Weapon.SPREAD)
		"railgun":
			_set_weapon(Weapon.RAILGUN)
		"homing":
			_set_weapon(Weapon.HOMING)
		"wave":
			_set_weapon(Weapon.WAVE)
		"flak":
			_set_weapon(Weapon.FLAK)
		"power":
			_power_up()
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
