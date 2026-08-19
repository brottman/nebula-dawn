extends CharacterBody2D
## Player strike craft — movement, graze, and a facade over WeaponSystem / LifeSystem.
## Color-coded weapons + universal power level:
##   Red = Spread, Blue = Laser (solid piercing column), Green = Homing.
##   Gold Power pickups raise the shared tier (Lv1→2→3). Swapping color keeps the tier.
## Hull damage resets to Blaster Lv1 (power tier lost). Bits/Speed persist.

const PLAYFIELD_MARGIN := 24.0
const TOUCH_FOLLOW := 28.0
const GRAZE_RADIUS := 30.0
const SPEED_STACK_BONUS := 0.12

enum Weapon { BLASTER, VULCAN, LASER, HOMING }

@export var move_speed: float = 310.0
@export var max_hp: int = 7
@export var fire_cooldown: float = 0.16
@export var bullet_speed: float = 560.0
@export var bullet_damage: float = 1.0

var hp: int = 5
var invuln_time: float = 0.0
var shield_charges: int = 0
var bomb_stock: int = 0
var lives: int = 3
var rapid_time: float = 0.0
var weapon: int = Weapon.BLASTER
var weapon_level: int = 1
var chip_progress: int = 0
var _life_peak_weapon: int = Weapon.BLASTER
var _life_peak_level: int = 1
var _life_peak_chips: int = 0
var _death_bomb_time: float = 0.0
var _respawning: bool = false
var drone_count: int = 0
var speed_stacks: int = 0
var _flash_timer: float = 0.0
var dead: bool = false

var plasma_active: bool = false
var damage_mult: float = 1.0
var secondaries_disabled: bool = false
var scrap_push: float = 0.0

var overdrive: float = 0.0
var overdrive_time: float = 0.0

var projectile_pool: ProjectilePool

var _touch_active: bool = false
var _touch_index: int = -1
var _touch_world: Vector2 = Vector2.ZERO
var _touch_grab_offset: Vector2 = Vector2.ZERO
var _cinematic: bool = false

var _graze_zone: Area2D
var _grazed: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _poly: Polygon2D = $Polygon2D
@onready var _shield_visual: Polygon2D = $ShieldVisual
@onready var _shield_visual_inner: Polygon2D = $ShieldVisualInner
@onready var _engine: GPUParticles2D = $EngineParticles
const _WeaponSystem := preload("res://scripts/player/weapon_system.gd")
const _LifeSystem := preload("res://scripts/player/life_system.gd")
@onready var weapons: _WeaponSystem = $WeaponSystem
@onready var life: _LifeSystem = $LifeSystem

const _SHIP_FLASH := Color(1.6, 1.6, 1.6, 1.0)
const MAX_BANK := 0.38
const BANK_RATE := 9.0
var _ship_tint := Color(1.0, 1.0, 1.0, 1.0)
## Path of the loadout hull sprite — drones copy this to look like mini ships.
var _visual_sprite_path: String = "res://assets/sprites/player_ship.svg"
var _bank: float = 0.0
var _last_x: float = 0.0
## Measured lateral speed this frame — banking source that works for both
## keyboard and touch movement (touch mode zeroes velocity).
var bank_vx: float = 0.0


func _ready() -> void:
	add_to_group("player")
	weapons.bind(self)
	life.bind(self)
	apply_hangar_loadout()
	life.reset_run()
	_update_shield_visuals()
	_last_x = global_position.x
	if _sprite and _sprite.texture:
		_poly.visible = false
	_build_graze_zone()
	if GameState.mode == GameState.Mode.BOSS_RUSH:
		set_boss_rush_loadout()
	EventBus.player_hp_changed.emit(hp, max_hp)
	EventBus.player_lives_changed.emit(lives)
	EventBus.bomb_stock_changed.emit(bomb_stock)
	_emit_weapon_changed()


func apply_hangar_loadout() -> void:
	var spec: Dictionary = GameState.get_active_loadout()
	max_hp = int(spec.get("max_hp", 7))
	move_speed = float(spec.get("move_speed", 310.0))
	fire_cooldown = float(spec.get("fire_cooldown", 0.16))
	bullet_speed = float(spec.get("bullet_speed", 560.0))
	bullet_damage = float(spec.get("bullet_damage", 1.0))
	var tint_val: Variant = spec.get("tint", Color(1.0, 1.0, 1.0, 1.0))
	if tint_val is Color:
		_ship_tint = tint_val
	else:
		_ship_tint = Color(1.0, 1.0, 1.0, 1.0)
	var path := String(spec.get("sprite", "res://assets/sprites/player_ship.svg"))
	if ResourceLoader.exists(path):
		_visual_sprite_path = path
		if _sprite and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_sprite.texture = tex
				_sprite.visible = true
				if _poly:
					_poly.visible = false
	var vis := _visual()
	vis.modulate = _ship_tint


func _build_graze_zone() -> void:
	_graze_zone = Area2D.new()
	_graze_zone.name = "GrazeZone"
	_graze_zone.collision_layer = 0
	_graze_zone.collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GRAZE_RADIUS
	shape.shape = circle
	_graze_zone.add_child(shape)
	add_child(_graze_zone)
	_graze_zone.area_entered.connect(_on_graze_entered)
	_graze_zone.area_exited.connect(_on_graze_exited)


func _on_graze_entered(area: Area2D) -> void:
	if dead or not visible or not is_instance_valid(area):
		return
	if not area.is_in_group("enemy_projectiles"):
		return
	var id := area.get_instance_id()
	if _grazed.has(id):
		var stored: Node = _grazed[id]
		if stored == area and area.is_active():
			return
		_grazed.erase(id)
	_grazed[id] = area
	EventBus.graze_occurred.emit()
	AudioBus.play_graze()
	if not GameState.reduce_flashes:
		CombatFX.spawn_ring(get_parent(), global_position, Color(0.55, 0.95, 1.0), 9.0)


func _on_graze_exited(area: Area2D) -> void:
	_grazed.erase(area.get_instance_id())


func _visual() -> CanvasItem:
	return _sprite if _sprite and _sprite.visible else _poly


func _update_shield_visuals() -> void:
	_shield_visual.visible = shield_charges >= 2
	_shield_visual_inner.visible = shield_charges >= 1


func setup(pool: ProjectilePool) -> void:
	projectile_pool = pool
	weapons.attach_pool(pool)


func _unhandled_input(event: InputEvent) -> void:
	if _cinematic:
		return
	if _death_bomb_time > 0.0 and _is_bomb_press(event):
		_try_death_bomb()
		get_viewport().set_input_as_handled()
		return
	if dead:
		return
	if _is_bomb_press(event):
		try_use_bomb()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_active = true
			_touch_index = touch.index
			_touch_world = _screen_to_world(touch.position)
			_touch_grab_offset = global_position - _touch_world
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


func _is_bomb_press(event: InputEvent) -> bool:
	if event.is_action_pressed("bomb"):
		return true
	return false


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _physics_process(delta: float) -> void:
	if _cinematic:
		weapons.extinguish_laser()
		return
	if _death_bomb_time > 0.0:
		weapons.extinguish_laser()
		life.tick_death_bomb(delta)
		return
	if dead:
		weapons.extinguish_laser()
		return
	life.update_timers(delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
	_handle_movement(delta)
	weapons.tick_fire(delta)
	if Input.is_action_just_pressed("bomb"):
		try_use_bomb()
	if Input.is_action_just_pressed("weapon_switch"):
		cycle_weapon()
	_update_visuals(delta)


func enter_plasma() -> void:
	life.enter_plasma()


func exit_plasma() -> void:
	life.exit_plasma()


func clear_zone_effects() -> void:
	life.clear_zone_effects()


func add_overdrive(amount: float) -> void:
	life.add_overdrive(amount)


func _handle_movement(delta: float) -> void:
	var vp := get_viewport_rect().size
	var speed_mult := 1.0 + SPEED_STACK_BONUS * float(speed_stacks)
	if _touch_active:
		var follow := TOUCH_FOLLOW * GameState.touch_sensitivity * (1.0 + 0.15 * float(speed_stacks))
		var target := _touch_world + _touch_grab_offset
		global_position = global_position.lerp(target, 1.0 - exp(-follow * delta))
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * move_speed * speed_mult
		move_and_slide()
	if absf(scrap_push) > 0.01:
		global_position.x += scrap_push * delta
	global_position.x = clampf(global_position.x, PLAYFIELD_MARGIN, vp.x - PLAYFIELD_MARGIN)
	global_position.y = clampf(global_position.y, PLAYFIELD_MARGIN, vp.y - PLAYFIELD_MARGIN)
	_resolve_barrier_overlap()


func _resolve_barrier_overlap() -> void:
	if not is_inside_tree():
		return
	var half := Vector2(15.0, 16.0)
	var ship := Rect2(global_position - half, half * 2.0)
	for b in get_tree().get_nodes_in_group("barriers"):
		if not b.has_method("get_solid_rect"):
			continue
		var r: Rect2 = b.get_solid_rect()
		if r.size.x <= 0.0 or not ship.intersects(r):
			continue
		var overlap := ship.intersection(r)
		if overlap.size.y < overlap.size.x:
			var dir := 1.0 if global_position.y < r.get_center().y else -1.0
			global_position.y = r.position.y + r.size.y * (0.0 if dir < 0.0 else 1.0) + dir * half.y
		else:
			var dir := 1.0 if global_position.x < r.get_center().x else -1.0
			global_position.x = r.position.x + r.size.x * (0.0 if dir < 0.0 else 1.0) + dir * half.x


func set_boss_rush_loadout() -> void:
	weapons.set_boss_rush_loadout()


func restore_full() -> void:
	life.restore_full()


func _emit_weapon_changed() -> void:
	weapons.emit_changed()


func cycle_weapon() -> bool:
	if dead or _cinematic or _respawning:
		return false
	return weapons.cycle_weapon()


func take_damage(amount: int) -> void:
	life.take_damage(amount)


func add_shield(charges: int = 2) -> void:
	life.add_shield(charges)


func add_bomb(count: int = 1) -> void:
	life.add_bomb(count)


func try_use_bomb() -> bool:
	return life.try_use_bomb()


func _try_death_bomb() -> void:
	life.try_death_bomb()


func activate_bomb() -> void:
	life.activate_bomb()


func apply_power_orb(amount: float) -> void:
	weapons.apply_power_orb(amount)


func _spawn_volcano_drop_now() -> void:
	life.spawn_volcano_drop_now()


func play_victory_exit() -> void:
	if dead or not is_inside_tree():
		return
	_cinematic = true
	_touch_active = false
	_touch_index = -1
	invuln_time = 999.0
	velocity = Vector2.ZERO
	clear_zone_effects()
	weapons.hide_drones()
	weapons.extinguish_laser()
	if _engine:
		_engine.emitting = true
	var vis := _visual()
	vis.modulate = _ship_tint
	_bank = 0.0
	_last_x = global_position.x
	var lvl := create_tween()
	lvl.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lvl.tween_property(vis, "rotation", 0.0, 0.22)
	await lvl.finished
	if not is_inside_tree():
		return

	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.48)
	var offscreen := Vector2(vp.x * 0.5, -120.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", center, 1.15)
	tween.tween_property(self, "global_position", center + Vector2(0, -10), 0.35)
	tween.tween_property(self, "global_position", center + Vector2(0, 8), 0.35)
	tween.tween_property(self, "global_position", center, 0.3)
	tween.tween_interval(0.35)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", offscreen, 0.75)
	tween.parallel().tween_property(self, "scale", Vector2(0.7, 1.45), 0.75)
	tween.parallel().tween_property(vis, "modulate:a", 0.0, 0.55).set_delay(0.2)
	await tween.finished
	visible = false


func apply_pickup(kind: String) -> void:
	match kind:
		"spread", "vulcan", "red":
			weapons.set_weapon(Weapon.VULCAN)
		"laser", "beam", "blue":
			weapons.set_weapon(Weapon.LASER)
		"homing", "missiles", "green":
			weapons.set_weapon(Weapon.HOMING)
		"power", "pchip", "p-chip", "gold":
			weapons.power_up()
		"power_orb", "orb":
			weapons.apply_power_orb(2.0)
		"option", "bit", "drone":
			weapons.add_drone()
		"speed":
			weapons.add_speed()
		"shield", "barrier":
			life.add_shield(2)
		"bomb", "cleaver":
			life.add_bomb(1)
		"energy", "overdrive_pickup", "rapid", "heal":
			if hp < max_hp:
				hp = mini(max_hp, hp + 1)
				EventBus.player_hp_changed.emit(hp, max_hp)
	AudioBus.play_pickup()
	EventBus.pickup_collected.emit(kind)


func _update_visuals(delta: float) -> void:
	var vis := _visual()
	# Banking roll — tilt the hull toward measured lateral movement.
	var vx := (global_position.x - _last_x) / maxf(delta, 0.0001)
	_last_x = global_position.x
	bank_vx = vx
	var bank_target := clampf(vx / maxf(move_speed, 1.0), -1.0, 1.0) * MAX_BANK
	_bank = lerpf(_bank, bank_target, 1.0 - exp(-BANK_RATE * delta))
	vis.rotation = _bank
	if invuln_time > 0.0:
		if GameState.reduce_flashes:
			vis.modulate.a = 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		else:
			vis.modulate.a = 0.35 if int(Time.get_ticks_msec() / 60) % 2 == 0 else 1.0
	else:
		vis.modulate.a = 1.0
	if _flash_timer > 0.0:
		vis.modulate = Color(_SHIP_FLASH.r, _SHIP_FLASH.g, _SHIP_FLASH.b, vis.modulate.a)
	else:
		vis.modulate = Color(_ship_tint.r, _ship_tint.g, _ship_tint.b, vis.modulate.a)
	if vis == _poly:
		_poly.color = Color(1.0, 1.0, 1.0) if _flash_timer > 0.0 else Color(0.43, 0.78, 1.0)
	if _engine:
		_engine.emitting = not dead