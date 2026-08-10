extends CharacterBody2D
## Player strike craft — touch-drag or 8-way move, auto-fire, power-ups.
## Color-coded weapons + universal power level:
##   Red = Spread, Blue = Laser, Green = Homing.
##   Gold P-Chips raise the shared tier (Lv1→2→3). Swapping color keeps the tier.
## Hull damage resets to Blaster Lv1 (power tier lost). Bits/Speed persist.

const PLAYFIELD_MARGIN := 24.0
## How quickly the ship catches relative touch motion (higher = snappier).
const TOUCH_FOLLOW := 28.0
## Shared power tier for every color weapon (Lv1–Lv3).
const MAX_WEAPON_LEVEL := 3
## P-Chips needed to climb one tier (segmented HUD bar).
const CHIPS_PER_LEVEL := 5
const MAX_BITS := 2
const MAX_SPEED_STACKS := 3
const SPEED_STACK_BONUS := 0.12 ## +12% move speed per stack
## Graze ring radius around the ship (larger than the hitbox on purpose).
const GRAZE_RADIUS := 30.0

enum Weapon { BLASTER, VULCAN, LASER, HOMING }

const WEAPON_NAMES := {
	Weapon.BLASTER: "BLASTER",
	Weapon.VULCAN: "SPREAD",
	Weapon.LASER: "LASER",
	Weapon.HOMING: "HOMING",
}
const WEAPON_TITLES := {
	Weapon.BLASTER: "BLASTER",
	Weapon.VULCAN: "SPREAD BEAM",
	Weapon.LASER: "FOCUSED LASER",
	Weapon.HOMING: "HOMING MISS",
}
## Base cooldowns; per-level modifiers applied in _weapon_cooldown().
const WEAPON_COOLDOWNS := {
	Weapon.BLASTER: 0.16,
	Weapon.VULCAN: 0.16, ## Red Spread — Lv2 speeds up
	Weapon.LASER: 0.42, ## Blue Laser
	Weapon.HOMING: 0.45, ## Green Homing — Lv3 rapid-fires
}

@export var move_speed: float = 310.0
@export var max_hp: int = 7
@export var fire_cooldown: float = 0.16
@export var bullet_speed: float = 560.0
@export var bullet_damage: float = 1.0

var hp: int = 5
var invuln_time: float = 0.0
## Hit-based barrier (rare Shield drops). Absorbs 1–2 hits.
var shield_charges: int = 0
const MAX_SHIELD_CHARGES := 2
## Stocked smart bombs (pickup adds stock; B / bomb button spends one).
var bomb_stock: int = 0
const MAX_BOMB_STOCK := 3
## Lives remaining (including the current ship).
var lives: int = 3
const START_LIVES := 3
## Death-bomb panic window (seconds).
const DEATH_BOMB_WINDOW := 0.25
## Post-respawn invulnerability for volcano recovery sweeps.
const RESPAWN_INVULN := 2.5
## Timed fire-rate buff (Energy / temporary Overdrive pickup).
var rapid_time: float = 0.0
## Timed invulnerability window from Energy pickup (stacks with rapid).
var energy_time: float = 0.0
var weapon: int = Weapon.BLASTER
var weapon_level: int = 1
## P-Chips banked toward the next tier (0 … CHIPS_PER_LEVEL-1).
var chip_progress: int = 0
## Peak loadout this life — volcano orbs rebuild toward this.
var _life_peak_weapon: int = Weapon.BLASTER
var _life_peak_level: int = 1
var _life_peak_chips: int = 0
var _death_bomb_time: float = 0.0
var _respawning: bool = false
## Stackable sub-systems (persist through hull hits; cleared on death / new run).
var bit_count: int = 0
var speed_stacks: int = 0
var _bits: Array[BitDrone] = []
var _fire_timer: float = 0.0
var _flash_timer: float = 0.0
var dead: bool = false

## Stage 3 plasma: +50% damage, secondaries disabled.
var plasma_active: bool = false
var damage_mult: float = 1.0
var secondaries_disabled: bool = false
## Sector 2 scrap conveyor horizontal shove (px/sec).
var scrap_push: float = 0.0

## Stage 5 overdrive (filled by grazing singularities).
var overdrive: float = 0.0
const OVERDRIVE_MAX := 100.0
var overdrive_time: float = 0.0

var projectile_pool: ProjectilePool

var _touch_active: bool = false
var _touch_index: int = -1
var _touch_world: Vector2 = Vector2.ZERO
## Ship position relative to the finger at grab time (keeps the craft from jumping).
var _touch_grab_offset: Vector2 = Vector2.ZERO
var _cinematic: bool = false

## Graze ring + per-bullet tracking so a single bullet only pays once per pass.
var _graze_zone: Area2D
var _grazed: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _poly: Polygon2D = $Polygon2D
@onready var _shield_visual: Polygon2D = $ShieldVisual
@onready var _engine: GPUParticles2D = $EngineParticles

const _SHIP_TINT := Color(1.0, 1.0, 1.0, 1.0)
const _SHIP_FLASH := Color(1.6, 1.6, 1.6, 1.0)


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	lives = START_LIVES
	bomb_stock = 0
	_shield_visual.visible = false
	if _sprite and _sprite.texture:
		_poly.visible = false
	_build_graze_zone()
	if GameState.mode == GameState.Mode.BOSS_RUSH:
		set_boss_rush_loadout()
	EventBus.player_hp_changed.emit(hp, max_hp)
	EventBus.player_lives_changed.emit(lives)
	EventBus.bomb_stock_changed.emit(bomb_stock)
	_emit_weapon_changed()


func _build_graze_zone() -> void:
	_graze_zone = Area2D.new()
	_graze_zone.name = "GrazeZone"
	_graze_zone.collision_layer = 0
	_graze_zone.collision_mask = 8 ## enemy projectiles only
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


func setup(pool: ProjectilePool) -> void:
	projectile_pool = pool
	for bit in _bits:
		if is_instance_valid(bit):
			bit.projectile_pool = pool


func _unhandled_input(event: InputEvent) -> void:
	if _cinematic:
		return
	# Death-bomb window still accepts bomb even while "dying".
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
			# Relative grab: ship keeps its current place vs the finger.
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
		return
	if _death_bomb_time > 0.0:
		_death_bomb_time -= delta
		if Input.is_action_just_pressed("bomb"):
			_try_death_bomb()
			return
		if _death_bomb_time <= 0.0:
			_confirm_death()
		return
	if dead:
		return
	_update_timers(delta)
	_handle_movement(delta)
	_handle_fire(delta)
	if Input.is_action_just_pressed("bomb"):
		try_use_bomb()
	_update_visuals(delta)


func _update_timers(delta: float) -> void:
	if invuln_time > 0.0:
		invuln_time -= delta
	if energy_time > 0.0:
		energy_time -= delta
		if energy_time <= 0.0 and overdrive_time <= 0.0:
			EventBus.gimmick_toast.emit("ENERGY END")
	_shield_visual.visible = shield_charges > 0
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
	scrap_push = 0.0
	overdrive_time = 0.0
	energy_time = 0.0
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
	var speed_mult := 1.0 + SPEED_STACK_BONUS * float(speed_stacks)
	if _touch_active:
		# Match finger motion 1:1 while preserving the grab-time offset.
		# Speed stacks / settings make catch-up snappier without breaking relative control.
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


func _weapon_cooldown() -> float:
	var cd: float = WEAPON_COOLDOWNS.get(weapon, fire_cooldown)
	match weapon:
		Weapon.VULCAN:
			# Lv2+ increased firing speed.
			if weapon_level >= 2:
				cd = 0.11
			if weapon_level >= 3:
				cd = 0.12 ## slightly slower than Lv2 to feed the side waves
		Weapon.LASER:
			if weapon_level >= 3:
				cd = 0.50 ## mega beam — denser, slightly slower cadence
		Weapon.HOMING:
			if weapon_level == 2:
				cd = 0.34
			elif weapon_level >= 3:
				cd = 0.22 ## rapid-fire volleys
	return cd


func _handle_fire(delta: float) -> void:
	_fire_timer -= delta
	# Auto-fire; hold also works (same path)
	if _fire_timer > 0.0:
		return
	var cd := _weapon_cooldown()
	cd *= 0.45 if (rapid_time > 0.0 or energy_time > 0.0) else 1.0
	_fire_timer = cd
	_shoot()
	_fire_bits()


func _set_weapon(w: int) -> void:
	## Color swap — type changes, universal power level + chip bank are kept.
	## Same color again acts as a free P-Chip (classic arcade feel).
	if weapon == w and weapon != Weapon.BLASTER:
		_power_up()
		return
	var prev_level := weapon_level
	weapon = w
	weapon_level = clampi(prev_level, 1, MAX_WEAPON_LEVEL)
	_note_peak_loadout()
	GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, weapon_level)
	_emit_weapon_changed()
	EventBus.gimmick_toast.emit("%s  Lv%d" % [WEAPON_NAMES[weapon], weapon_level])


func _power_up() -> void:
	## Gold P-Chip — fills one segment toward the next tier.
	_add_chips(1)


func _add_chips(count: int) -> void:
	if count <= 0:
		return
	if weapon == Weapon.BLASTER:
		# Stock blaster ignores chips until a color is equipped.
		GameState.add_score(40 * count)
		EventBus.gimmick_toast.emit("NEED COLOR")
		return
	if weapon_level >= MAX_WEAPON_LEVEL:
		chip_progress = CHIPS_PER_LEVEL
		GameState.add_score(150 * count)
		EventBus.gimmick_toast.emit("POWER MAX")
		_emit_weapon_changed()
		return
	for _i in count:
		chip_progress += 1
		if chip_progress >= CHIPS_PER_LEVEL:
			chip_progress = 0
			weapon_level = mini(MAX_WEAPON_LEVEL, weapon_level + 1)
			_note_peak_loadout()
			GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, weapon_level)
			if weapon_level >= MAX_WEAPON_LEVEL:
				chip_progress = CHIPS_PER_LEVEL
				EventBus.gimmick_toast.emit("POWER  MAX")
				break
			EventBus.gimmick_toast.emit("POWER  Lv%d" % weapon_level)
		else:
			EventBus.gimmick_toast.emit("P-CHIP  %d/%d" % [chip_progress, CHIPS_PER_LEVEL])
	_note_peak_loadout()
	_emit_weapon_changed()


func _note_peak_loadout() -> void:
	if weapon == Weapon.BLASTER:
		return
	_life_peak_weapon = weapon
	if weapon_level > _life_peak_level:
		_life_peak_level = weapon_level
		_life_peak_chips = chip_progress
	elif weapon_level == _life_peak_level:
		_life_peak_chips = maxi(_life_peak_chips, chip_progress)


func _add_bit() -> void:
	if bit_count >= MAX_BITS:
		GameState.add_score(120)
		EventBus.gimmick_toast.emit("BITS MAX")
		return
	var bit := BitDrone.new()
	add_child(bit)
	bit.setup(self, projectile_pool, bit_count)
	_bits.append(bit)
	bit_count = _bits.size()
	EventBus.gimmick_toast.emit("BIT  ×%d" % bit_count)
	_emit_weapon_changed()


func _add_speed() -> void:
	if speed_stacks >= MAX_SPEED_STACKS:
		GameState.add_score(100)
		EventBus.gimmick_toast.emit("SPEED MAX")
		return
	speed_stacks += 1
	EventBus.gimmick_toast.emit("SPEED  ×%d" % speed_stacks)
	_emit_weapon_changed()


func _fire_bits() -> void:
	if secondaries_disabled:
		return
	for bit in _bits:
		if is_instance_valid(bit):
			bit.fire(damage_mult)


func _clear_bits() -> void:
	for bit in _bits:
		if is_instance_valid(bit):
			bit.queue_free()
	_bits.clear()
	bit_count = 0


## Losing hull integrity knocks the ship back to the stock blaster (power tier resets).
## Bits and speed stacks are sub-systems and persist.
func _reset_weapon() -> void:
	if weapon == Weapon.BLASTER and weapon_level == 1 and chip_progress == 0:
		return
	weapon = Weapon.BLASTER
	weapon_level = 1
	chip_progress = 0
	_emit_weapon_changed()


## Practice mode: start with the stock blaster at the chosen tier.
func apply_starting_power(level: int) -> void:
	weapon = Weapon.BLASTER
	weapon_level = clampi(level, 1, MAX_WEAPON_LEVEL)
	chip_progress = CHIPS_PER_LEVEL if weapon_level >= MAX_WEAPON_LEVEL else 0
	_note_peak_loadout()
	GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, weapon_level)
	_emit_weapon_changed()


## Boss Rush: fixed loadout so every run starts on equal footing.
func set_boss_rush_loadout() -> void:
	weapon = Weapon.HOMING
	weapon_level = 2
	chip_progress = 0
	_note_peak_loadout()
	GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, weapon_level)
	_emit_weapon_changed()


## Boss Rush intermission: full hull repair between targets.
func restore_full() -> void:
	hp = max_hp
	EventBus.player_hp_changed.emit(hp, max_hp)


func _emit_weapon_changed() -> void:
	var slot: String = WEAPON_NAMES.get(weapon, "BLASTER")
	var parts: PackedStringArray = []
	if weapon != Weapon.BLASTER:
		parts.append("%s Lv%d" % [slot, weapon_level])
	elif weapon_level > 1:
		parts.append("BLASTER Lv%d" % weapon_level)
	var extras_parts: PackedStringArray = []
	if bit_count > 0:
		extras_parts.append("BIT×%d" % bit_count)
	if speed_stacks > 0:
		extras_parts.append("SPD×%d" % speed_stacks)
	parts.append_array(extras_parts)
	EventBus.weapon_changed.emit("  ".join(parts))
	var chips := chip_progress
	var needed := CHIPS_PER_LEVEL
	if weapon_level >= MAX_WEAPON_LEVEL:
		chips = CHIPS_PER_LEVEL
	elif weapon == Weapon.BLASTER:
		chips = 0
	EventBus.weapon_tier_changed.emit(slot, weapon_level, chips, needed, "  ".join(extras_parts))


func _shoot() -> void:
	if projectile_pool == null:
		return
	var origin := global_position + Vector2(0, -18)
	var dmg := bullet_damage * damage_mult
	var active_weapon := weapon
	# Stage 3 plasma fields lock secondaries; fall back to the stock blaster.
	if secondaries_disabled and weapon != Weapon.BLASTER:
		active_weapon = Weapon.BLASTER
	match active_weapon:
		Weapon.VULCAN:
			_shoot_spread(origin, dmg)
		Weapon.LASER:
			_shoot_laser(origin)
		Weapon.HOMING:
			_shoot_homing(origin)
		_:
			# Stock blaster — straight parallel bolts.
			for i in weapon_level:
				var offset := (i - (weapon_level - 1) * 0.5) * 12.0
				projectile_pool.spawn_player(origin + Vector2(offset, 0.0), Vector2(0, -bullet_speed), dmg)
			AudioBus.play_shoot()


func _shoot_spread(origin: Vector2, dmg: float) -> void:
	## Red — Lv1 3-way / Lv2 5-way + ROF / Lv3 7-way + side-cancellation waves.
	var count := 1 + weapon_level * 2 ## 3 / 5 / 7
	var spread := 0.42 + 0.10 * weapon_level
	var shot_dmg := dmg * (0.85 + 0.05 * weapon_level)
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var dir := Vector2(-spread + 2.0 * spread * t, -1.0).normalized()
		projectile_pool.spawn_player(origin, dir * (bullet_speed * 0.95), shot_dmg, {
			"scale": 0.85, "color": Color(1.0, 0.35, 0.32), "lifetime": 1.6})
	if weapon_level >= 3:
		# Lateral cancellation waves — clear enemy bullets on contact.
		for side in [-1.0, 1.0]:
			projectile_pool.spawn_player(origin + Vector2(side * 10.0, 0.0), Vector2(side * 90.0, -420.0), shot_dmg * 0.55, {
				"wave_amp": side * 36.0,
				"wave_freq": 9.0,
				"cancel_bullets": true,
				"scale": 1.2,
				"color": Color(1.0, 0.55, 0.4),
				"lifetime": 1.4})
	AudioBus.play_shoot(720.0)


func _shoot_laser(origin: Vector2) -> void:
	## Blue — Lv1 single / Lv2 dual + pierce / Lv3 mega beam + melt ticks.
	match weapon_level:
		1:
			projectile_pool.spawn_player(origin, Vector2(0, -920.0), 2.6 * damage_mult, {
				"scale": 1.25, "color": Color(0.4, 0.75, 1.0), "lifetime": 0.85})
		2:
			# Dual parallel beams with armor pierce.
			for side in [-1.0, 1.0]:
				projectile_pool.spawn_player(origin + Vector2(side * 7.0, 0.0), Vector2(0, -940.0), 2.8 * damage_mult, {
					"pierce": 18,
					"armor_pierce": true,
					"scale": 1.2,
					"color": Color(0.45, 0.82, 1.0),
					"lifetime": 0.9})
		_:
			# High-density mega beam + melt ticks.
			projectile_pool.spawn_player(origin, Vector2(0, -980.0), 4.2 * damage_mult, {
				"pierce": 28,
				"armor_pierce": true,
				"scale": 2.1,
				"color": Color(0.55, 0.9, 1.0),
				"lifetime": 0.95,
				"melt_ticks": 6,
				"melt_dps": 0.55 * damage_mult})
			for side in [-1.0, 1.0]:
				projectile_pool.spawn_player(origin + Vector2(side * 10.0, 0.0), Vector2(0, -920.0), 1.6 * damage_mult, {
					"pierce": 10, "armor_pierce": true, "scale": 0.9, "color": Color(0.7, 0.95, 1.0), "lifetime": 0.8})
	AudioBus.play_shoot(1250.0)


func _shoot_homing(origin: Vector2) -> void:
	## Green — Lv1 2 slow / Lv2 4 fast micro / Lv3 6 rapid + splash.
	match weapon_level:
		1:
			for i in 2:
				var dir := Vector2((-0.28 if i == 0 else 0.28), -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * 260.0, 1.35 * damage_mult, {
					"homing": 7.0, "scale": 1.25, "color": Color(0.35, 1.0, 0.45), "lifetime": 3.0})
		2:
			for i in 4:
				var dir := Vector2((i - 1.5) * 0.28, -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * 420.0, 0.95 * damage_mult, {
					"homing": 12.0, "scale": 0.8, "color": Color(0.45, 1.0, 0.55), "lifetime": 2.4})
		_:
			for i in 6:
				var dir := Vector2((i - 2.5) * 0.22, -1.0).normalized()
				projectile_pool.spawn_player(origin, dir * 400.0, 1.05 * damage_mult, {
					"homing": 14.0,
					"scale": 0.95,
					"color": Color(0.3, 1.0, 0.5),
					"lifetime": 2.6,
					"splash_radius": 42.0,
					"splash_damage": 0.7 * damage_mult})
	AudioBus.play_shoot(600.0)


func take_damage(amount: int) -> void:
	if dead or _cinematic or _respawning or invuln_time > 0.0 or energy_time > 0.0:
		return
	if _death_bomb_time > 0.0:
		return
	if shield_charges > 0:
		shield_charges -= 1
		_shield_visual.visible = shield_charges > 0
		invuln_time = 0.75
		AudioBus.play_player_hurt()
		EventBus.screen_shake.emit(4.0, 0.12)
		EventBus.gimmick_toast.emit("SHIELD BREAK" if shield_charges <= 0 else "SHIELD  ×%d" % shield_charges)
		return
	# Lethal hit → brief death-bomb window if a bomb is stocked.
	if hp - amount <= 0:
		if bomb_stock > 0:
			hp = 0
			EventBus.player_hp_changed.emit(hp, max_hp)
			_death_bomb_time = DEATH_BOMB_WINDOW
			invuln_time = DEATH_BOMB_WINDOW
			EventBus.gimmick_toast.emit("DEATH BOMB!")
			EventBus.screen_shake.emit(6.0, 0.1)
			return
		hp = 0
		EventBus.player_hp_changed.emit(hp, max_hp)
		_confirm_death()
		return
	hp = maxi(0, hp - amount)
	_reset_weapon()
	invuln_time = 1.35
	_flash_timer = 0.2
	EventBus.player_hull_hit.emit()
	AudioBus.play_player_hurt()
	EventBus.screen_shake.emit(8.0, 0.18)
	EventBus.hitstop_requested.emit(0.07)
	EventBus.player_hp_changed.emit(hp, max_hp)


func add_shield(charges: int = 2) -> void:
	shield_charges = mini(MAX_SHIELD_CHARGES, shield_charges + charges)
	_shield_visual.visible = true
	EventBus.gimmick_toast.emit("SHIELD  ×%d" % shield_charges)


func add_bomb(count: int = 1) -> void:
	bomb_stock = mini(MAX_BOMB_STOCK, bomb_stock + count)
	EventBus.bomb_stock_changed.emit(bomb_stock)
	EventBus.gimmick_toast.emit("BOMB  ×%d" % bomb_stock)


func try_use_bomb() -> bool:
	if dead or _cinematic or bomb_stock <= 0:
		return false
	bomb_stock -= 1
	EventBus.bomb_stock_changed.emit(bomb_stock)
	activate_bomb()
	invuln_time = maxf(invuln_time, 0.85)
	return true


func _try_death_bomb() -> void:
	if _death_bomb_time <= 0.0 or bomb_stock <= 0:
		return
	_death_bomb_time = 0.0
	bomb_stock -= 1
	EventBus.bomb_stock_changed.emit(bomb_stock)
	hp = 1
	EventBus.player_hp_changed.emit(hp, max_hp)
	activate_bomb()
	invuln_time = 1.6
	EventBus.gimmick_toast.emit("SAVED!")
	# Keep current loadout — panic save does not strip power.


func activate_energy(duration: float = 4.0) -> void:
	## Rare Energy drop — fire-rate boost + brief invulnerability.
	energy_time = maxf(energy_time, duration)
	rapid_time = maxf(rapid_time, duration)
	invuln_time = maxf(invuln_time, 0.35)
	EventBus.gimmick_toast.emit("ENERGY")


func activate_bomb() -> void:
	## Smart Cleaver — wipe enemy bullets and burst non-boss threats.
	EventBus.gimmick_toast.emit("BOMB")
	EventBus.screen_shake.emit(10.0, 0.22)
	EventBus.hitstop_requested.emit(0.08)
	AudioBus.play_bomb()
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var fx_parent := get_parent()
	if fx_parent:
		CombatFX.spawn_ring(fx_parent, global_position, Color(1.0, 0.75, 0.35), 28.0)
		CombatFX.spawn_burst(fx_parent, global_position, Color(1.0, 0.6, 0.25), 16, 48.0)
	if projectile_pool and projectile_pool.has_method("clear_enemy_in_radius"):
		projectile_pool.clear_enemy_in_radius(center, maxf(vp.x, vp.y) * 1.2)
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var is_stage_boss := n.is_in_group("boss") and not n.is_in_group("mid_boss")
		if is_stage_boss:
			n.take_damage(4.0) ## light chip only
		elif n.is_in_group("mid_boss"):
			n.take_damage(12.0)
		else:
			n.take_damage(10.0)
	for n in tree.get_nodes_in_group("hazards"):
		if n != null and is_instance_valid(n) and n.has_method("take_damage"):
			n.take_damage(6.0)


func _confirm_death() -> void:
	_death_bomb_time = 0.0
	_die()


func _die() -> void:
	if dead or _respawning:
		return
	dead = true
	_cinematic = false
	_touch_active = false
	_touch_index = -1
	_spawn_volcano_drop()
	_clear_bits()
	speed_stacks = 0
	shield_charges = 0
	rapid_time = 0.0
	energy_time = 0.0
	clear_zone_effects()
	visible = false
	set_physics_process(true) ## keep process for respawn scheduling via await
	AudioBus.play_explode()
	EventBus.screen_shake.emit(12.0, 0.28)
	EventBus.hitstop_requested.emit(0.18)
	var fx_parent := get_parent()
	if fx_parent:
		CombatFX.spawn_ring(fx_parent, global_position, Color(0.55, 0.9, 1.0), 16.0)
		CombatFX.spawn_burst(fx_parent, global_position, Color(0.7, 0.9, 1.0), 14, 34.0)
	lives -= 1
	EventBus.player_lives_changed.emit(lives)
	if lives <= 0:
		EventBus.player_died.emit()
		set_physics_process(false)
		return
	EventBus.gimmick_toast.emit("%d SHIP%s LEFT" % [lives, "S" if lives != 1 else ""])
	_respawn_after_delay()


func _respawn_after_delay() -> void:
	_respawning = true
	await get_tree().create_timer(1.05).timeout
	if not is_inside_tree() or lives <= 0:
		_respawning = false
		return
	_respawn()


func _respawn() -> void:
	var vp := get_viewport_rect().size
	global_position = Vector2(vp.x * 0.5, vp.y * 0.83)
	dead = false
	_respawning = false
	hp = max_hp
	invuln_time = RESPAWN_INVULN
	chip_progress = 0
	# Floor leveling — stage baseline power.
	var floor_lv := GameState.get_power_floor()
	if _life_peak_weapon != Weapon.BLASTER:
		weapon = _life_peak_weapon
		weapon_level = floor_lv
		if weapon_level >= MAX_WEAPON_LEVEL:
			chip_progress = CHIPS_PER_LEVEL
	else:
		weapon = Weapon.BLASTER
		weapon_level = 1
	# EX stages: guaranteed utility charge on respawn.
	if GameState.is_ex_stage():
		if randf() < 0.5:
			add_bomb(1)
		else:
			add_shield(1)
	visible = true
	scale = Vector2.ONE
	var vis := _visual()
	vis.modulate = _SHIP_TINT
	EventBus.player_hp_changed.emit(hp, max_hp)
	_emit_weapon_changed()
	EventBus.gimmick_toast.emit("RESPAWN  Lv%d" % weapon_level)


func _spawn_volcano_drop() -> void:
	## Eject 3–4 large Power Orbs that rebuild 50–75% of lost peak power (in P-Chips).
	## Deferred: death usually lands inside a physics callback.
	call_deferred("_spawn_volcano_drop_now")


func _spawn_volcano_drop_now() -> void:
	if not is_inside_tree() or dead:
		return
	var parent := get_parent()
	if parent == null:
		return
	var entities := parent.get_node_or_null("Entities")
	var host: Node = entities if entities else parent
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var floor_lv := GameState.get_power_floor()
	var peak_chips := (_life_peak_level - 1) * CHIPS_PER_LEVEL + _life_peak_chips
	var floor_chips := (floor_lv - 1) * CHIPS_PER_LEVEL
	var lost := maxi(0, peak_chips - floor_chips)
	var restore_pool := maxi(2, int(round(float(lost) * randf_range(0.50, 0.75))))
	var count := randi_range(3, 4)
	var base := restore_pool / count
	var rem := restore_pool % count
	for i in count:
		var p: Node = scene.instantiate()
		host.add_child(p)
		var ang := -PI * 0.5 + lerpf(-0.85, 0.85, float(i) / float(maxi(count - 1, 1)))
		var burst := Vector2(cos(ang), sin(ang)) * randf_range(36.0, 68.0)
		p.global_position = global_position + burst
		var chips_here := float(base + (1 if i < rem else 0))
		if p.has_method("set_volcano"):
			p.set_volcano(true)
		if p.has_method("setup"):
			p.setup("power_orb")
		p.orb_restore = maxf(1.0, chips_here)
		p.fall_speed = 38.0


func apply_power_orb(amount: float) -> void:
	## Volcano recovery — each orb grants P-Chip segments toward peak power.
	if amount <= 0.0:
		return
	if weapon == Weapon.BLASTER and _life_peak_weapon != Weapon.BLASTER:
		weapon = _life_peak_weapon
		weapon_level = maxi(weapon_level, GameState.get_power_floor())
		chip_progress = 0
	var chips := maxi(1, int(round(amount)))
	# Cap rebuild at this life's peak (level + chips).
	var peak_total := (_life_peak_level - 1) * CHIPS_PER_LEVEL + _life_peak_chips
	var cur_chips := chip_progress if weapon_level < MAX_WEAPON_LEVEL else CHIPS_PER_LEVEL
	var cur_total := (weapon_level - 1) * CHIPS_PER_LEVEL + cur_chips
	var room := maxi(0, peak_total - cur_total)
	if room <= 0:
		GameState.add_score(80)
		_emit_weapon_changed()
		return
	_add_chips(mini(chips, room))


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
	for bit in _bits:
		if is_instance_valid(bit):
			bit.visible = false
	if _engine:
		_engine.emitting = true
	var vis := _visual()
	vis.modulate = _SHIP_TINT

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
	tween.parallel().tween_property(vis, "modulate:a", 0.0, 0.55).set_delay(0.2)
	await tween.finished
	visible = false


func apply_pickup(kind: String) -> void:
	match kind:
		"spread", "vulcan", "red":
			_set_weapon(Weapon.VULCAN)
		"laser", "beam", "blue":
			_set_weapon(Weapon.LASER)
		"homing", "missiles", "green":
			_set_weapon(Weapon.HOMING)
		"power", "pchip", "p-chip", "gold":
			_power_up()
		"power_orb", "orb":
			apply_power_orb(2.0) ## fallback chips if orb_restore wasn't set
		"option", "bit", "drone":
			_add_bit()
		"speed":
			_add_speed()
		"shield", "barrier":
			add_shield(2)
		"bomb", "cleaver":
			add_bomb(1)
		"energy", "overdrive_pickup", "rapid":
			activate_energy(4.0)
		"heal":
			hp = mini(max_hp, hp + 1)
			EventBus.player_hp_changed.emit(hp, max_hp)
	AudioBus.play_pickup()
	EventBus.pickup_collected.emit(kind)


func _update_visuals(_delta: float) -> void:
	var vis := _visual()
	if invuln_time > 0.0 or energy_time > 0.0:
		if GameState.reduce_flashes:
			# Smooth pulse instead of a hard strobe.
			vis.modulate.a = 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		else:
			vis.modulate.a = 0.35 if int(Time.get_ticks_msec() / 60) % 2 == 0 else 1.0
	else:
		vis.modulate.a = 1.0
	if _flash_timer > 0.0:
		vis.modulate = Color(_SHIP_FLASH.r, _SHIP_FLASH.g, _SHIP_FLASH.b, vis.modulate.a)
	else:
		vis.modulate = Color(_SHIP_TINT.r, _SHIP_TINT.g, _SHIP_TINT.b, vis.modulate.a)
	# Keep polygon fallback tinted if sprite is missing.
	if vis == _poly:
		_poly.color = Color(1.0, 1.0, 1.0) if _flash_timer > 0.0 else Color(0.43, 0.78, 1.0)
	if _engine:
		_engine.emitting = not dead