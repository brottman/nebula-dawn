class_name WeaponSystem
extends Node
## Color weapons, shared power tier, drones, and speed stacks.
## Blue Laser is a continuous piercing column (see laser_beam.gd), not projectiles.

const Ships := preload("res://scripts/hangar/ship_catalog.gd")
const MAX_WEAPON_LEVEL := 3
const CHIPS_PER_LEVEL := 5
const MAX_DRONES := 2
const MAX_SPEED_STACKS := 3
const SPEED_STACK_BONUS := 0.12

const BLASTER := 0
const VULCAN := 1
const LASER := 2
const HOMING := 3

const WEAPON_NAMES := {
	BLASTER: "BLASTER",
	VULCAN: "SPREAD",
	LASER: "LASER",
	HOMING: "HOMING",
}

const WEAPON_COOLDOWNS := {
	BLASTER: 0.16,
	VULCAN: 0.16,
	LASER: 0.0,
	HOMING: 0.45,
}

const _LaserBeam := preload("res://scripts/player/laser_beam.gd")
const LASER_ORIGIN := Vector2(0, -18)
const LASER_DPS := {1: 14.0, 2: 20.0, 3: 28.0}
const LASER_HALF_W := {1: 7.0, 2: 13.0, 3: 22.0}

var ship: CharacterBody2D
var _drones: Array[Drone] = []
var _fire_timer: float = 0.0
var _laser: Node2D


func bind(host: CharacterBody2D) -> void:
	ship = host
	_ensure_laser()


func attach_pool(pool: ProjectilePool) -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.projectile_pool = pool


func tick_fire(delta: float) -> void:
	if _laser_active():
		_tick_laser(delta)
		return
	extinguish_laser()
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var cd := _weapon_cooldown()
	cd *= 0.45 if (float(ship.get("rapid_time")) > 0.0 or float(ship.get("energy_time")) > 0.0) else 1.0
	_fire_timer = cd
	_shoot()


func _weapon_cooldown() -> float:
	var weapon: int = ship.weapon
	var level: int = ship.weapon_level
	var cd: float = WEAPON_COOLDOWNS.get(weapon, Ships.BASE_FIRE_COOLDOWN)
	match weapon:
		VULCAN:
			if level >= 2:
				cd = 0.11
			if level >= 3:
				cd = 0.12
		HOMING:
			if level == 2:
				cd = 0.34
			elif level >= 3:
				cd = 0.22
	var hull_cd := float(ship.fire_cooldown)
	if Ships.BASE_FIRE_COOLDOWN > 0.0:
		cd *= hull_cd / Ships.BASE_FIRE_COOLDOWN
	return maxf(Ships.MIN_FIRE_COOLDOWN, cd)


func set_weapon(w: int) -> void:
	if ship.weapon == w and ship.weapon != BLASTER:
		power_up()
		return
	var prev_level: int = ship.weapon_level
	ship.weapon = w
	ship.weapon_level = clampi(prev_level, 1, MAX_WEAPON_LEVEL)
	note_peak_loadout()
	GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, ship.weapon_level)
	emit_changed()
	EventBus.gimmick_toast.emit("%s  Lv%d" % [WEAPON_NAMES[ship.weapon], ship.weapon_level])


func power_up() -> void:
	_add_chips(1)


func _add_chips(count: int) -> void:
	if count <= 0:
		return
	if ship.weapon == BLASTER:
		GameState.add_score(40 * count)
		EventBus.gimmick_toast.emit("NEED COLOR")
		return
	if ship.weapon_level >= MAX_WEAPON_LEVEL:
		ship.chip_progress = CHIPS_PER_LEVEL
		GameState.add_score(150 * count)
		EventBus.gimmick_toast.emit("POWER MAX")
		emit_changed()
		return
	for _i in count:
		ship.chip_progress += 1
		if ship.chip_progress >= CHIPS_PER_LEVEL:
			ship.chip_progress = 0
			ship.weapon_level = mini(MAX_WEAPON_LEVEL, ship.weapon_level + 1)
			note_peak_loadout()
			GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, ship.weapon_level)
			if ship.weapon_level >= MAX_WEAPON_LEVEL:
				ship.chip_progress = CHIPS_PER_LEVEL
				EventBus.gimmick_toast.emit("POWER  MAX")
				break
			EventBus.gimmick_toast.emit("POWER  Lv%d" % ship.weapon_level)
		else:
			EventBus.gimmick_toast.emit("POWER  %d/%d" % [ship.chip_progress, CHIPS_PER_LEVEL])
	note_peak_loadout()
	emit_changed()


func note_peak_loadout() -> void:
	if ship.weapon == BLASTER:
		return
	ship._life_peak_weapon = ship.weapon
	if ship.weapon_level > ship._life_peak_level:
		ship._life_peak_level = ship.weapon_level
		ship._life_peak_chips = ship.chip_progress
	elif ship.weapon_level == ship._life_peak_level:
		ship._life_peak_chips = maxi(ship._life_peak_chips, ship.chip_progress)


func add_drone() -> void:
	if ship.drone_count >= MAX_DRONES:
		GameState.add_score(120)
		EventBus.gimmick_toast.emit("DRONES MAX")
		return
	var drone := Drone.new()
	ship.add_child(drone)
	drone.setup(ship, ship.projectile_pool, ship.drone_count)
	_drones.append(drone)
	ship.drone_count = _drones.size()
	EventBus.gimmick_toast.emit("DRONE  ×%d" % ship.drone_count)
	emit_changed()


func add_speed() -> void:
	if ship.speed_stacks >= MAX_SPEED_STACKS:
		GameState.add_score(100)
		EventBus.gimmick_toast.emit("SPEED MAX")
		return
	ship.speed_stacks += 1
	EventBus.gimmick_toast.emit("SPEED  ×%d" % ship.speed_stacks)
	emit_changed()


func lose_drone() -> void:
	if _drones.is_empty():
		return
	var drone: Node = _drones.pop_back()
	if is_instance_valid(drone):
		drone.queue_free()
	ship.drone_count = _drones.size()
	EventBus.gimmick_toast.emit("DRONE LOST" if ship.drone_count == 0 else "DRONE  ×%d" % ship.drone_count)
	emit_changed()


func clear_drones() -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.queue_free()
	_drones.clear()
	ship.drone_count = 0


func hide_drones() -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.visible = false
	extinguish_laser()


func extinguish_laser() -> void:
	if _laser != null and is_instance_valid(_laser) and _laser.has_method("extinguish"):
		_laser.extinguish()


func reset_weapon() -> void:
	if ship.weapon == BLASTER and ship.weapon_level == 1 and ship.chip_progress == 0:
		return
	ship.weapon = BLASTER
	ship.weapon_level = 1
	ship.chip_progress = 0
	emit_changed()


func set_boss_rush_loadout() -> void:
	ship.weapon = HOMING
	ship.weapon_level = 2
	ship.chip_progress = 0
	note_peak_loadout()
	GameState.run_max_weapon_level = maxi(GameState.run_max_weapon_level, ship.weapon_level)
	emit_changed()


func restore_on_respawn(floor_lv: int) -> void:
	ship.chip_progress = 0
	if ship._life_peak_weapon != BLASTER:
		ship.weapon = ship._life_peak_weapon
		ship.weapon_level = floor_lv
		if ship.weapon_level >= MAX_WEAPON_LEVEL:
			ship.chip_progress = CHIPS_PER_LEVEL
	else:
		ship.weapon = BLASTER
		ship.weapon_level = 1


func apply_power_orb(amount: float) -> void:
	if amount <= 0.0:
		return
	if ship.weapon == BLASTER and ship._life_peak_weapon != BLASTER:
		ship.weapon = ship._life_peak_weapon
		ship.weapon_level = maxi(ship.weapon_level, GameState.get_power_floor())
		ship.chip_progress = 0
	var chips: int = maxi(1, int(round(amount)))
	var peak_total: int = (int(ship._life_peak_level) - 1) * CHIPS_PER_LEVEL + int(ship._life_peak_chips)
	var cur_chips: int = int(ship.chip_progress) if int(ship.weapon_level) < MAX_WEAPON_LEVEL else CHIPS_PER_LEVEL
	var cur_total: int = (int(ship.weapon_level) - 1) * CHIPS_PER_LEVEL + cur_chips
	var room: int = maxi(0, peak_total - cur_total)
	if room <= 0:
		GameState.add_score(80)
		emit_changed()
		return
	_add_chips(mini(chips, room))


func emit_changed() -> void:
	var slot: String = WEAPON_NAMES.get(ship.weapon, "BLASTER")
	var parts: PackedStringArray = []
	if ship.weapon != BLASTER:
		parts.append("%s Lv%d" % [slot, ship.weapon_level])
	elif ship.weapon_level > 1:
		parts.append("BLASTER Lv%d" % ship.weapon_level)
	var extras_parts: PackedStringArray = []
	if ship.drone_count > 0:
		extras_parts.append("DRONE×%d" % ship.drone_count)
	if ship.speed_stacks > 0:
		extras_parts.append("SPD×%d" % ship.speed_stacks)
	parts.append_array(extras_parts)
	EventBus.weapon_changed.emit("  ".join(parts))
	var chips: int = ship.chip_progress
	var needed := CHIPS_PER_LEVEL
	if ship.weapon_level >= MAX_WEAPON_LEVEL:
		chips = CHIPS_PER_LEVEL
	elif ship.weapon == BLASTER:
		chips = 0
	EventBus.weapon_tier_changed.emit(slot, ship.weapon_level, chips, needed, "  ".join(extras_parts))


func _shoot() -> void:
	if ship.projectile_pool == null:
		return
	var origin: Vector2 = ship.global_position + Vector2(0, -18)
	var dmg: float = ship.bullet_damage * ship.damage_mult
	var active_weapon: int = ship.weapon
	if ship.secondaries_disabled and ship.weapon != BLASTER:
		active_weapon = BLASTER
	match active_weapon:
		VULCAN:
			_shoot_spread(origin, dmg)
		HOMING:
			_shoot_homing(origin)
		_:
			for i in int(ship.weapon_level):
				var offset: float = (i - (int(ship.weapon_level) - 1) * 0.5) * 12.0
				ship.projectile_pool.spawn_player(origin + Vector2(offset, 0.0), Vector2(0, -ship.bullet_speed), dmg)
			AudioBus.play_shoot()


func _shoot_spread(origin: Vector2, dmg: float) -> void:
	var count: int = 1 + int(ship.weapon_level) * 2
	var spread: float = 0.42 + 0.10 * float(ship.weapon_level)
	var shot_dmg: float = dmg * (0.85 + 0.05 * float(ship.weapon_level))
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var dir := Vector2(-spread + 2.0 * spread * t, -1.0).normalized()
		ship.projectile_pool.spawn_player(origin, dir * (ship.bullet_speed * 0.95), shot_dmg, {
			"scale": 0.85, "color": Color(1.0, 0.35, 0.32), "lifetime": 1.6})
	if ship.weapon_level >= 3:
		for side in [-1.0, 1.0]:
			ship.projectile_pool.spawn_player(origin + Vector2(side * 10.0, 0.0), Vector2(side * 90.0, -420.0), shot_dmg * 0.55, {
				"wave_amp": side * 36.0,
				"wave_freq": 9.0,
				"cancel_bullets": true,
				"scale": 1.2,
				"color": Color(1.0, 0.55, 0.4),
				"lifetime": 1.4})
	AudioBus.play_shoot(720.0)


func _laser_active() -> bool:
	if ship == null or not is_instance_valid(ship):
		return false
	if bool(ship.get("dead")) or bool(ship.get("_cinematic")) or bool(ship.get("_respawning")):
		return false
	if bool(ship.secondaries_disabled) and ship.weapon != BLASTER:
		return false
	return ship.weapon == LASER


func _ensure_laser() -> void:
	if _laser != null and is_instance_valid(_laser):
		return
	_laser = _LaserBeam.new()
	_laser.name = "LaserBeam"
	ship.add_child(_laser)


func _tick_laser(delta: float) -> void:
	_ensure_laser()
	var level: int = clampi(int(ship.weapon_level), 1, MAX_WEAPON_LEVEL)
	var origin: Vector2 = ship.global_position + LASER_ORIGIN
	var half_w: float = float(LASER_HALF_W.get(level, 7.0))
	var dps: float = float(LASER_DPS.get(level, 14.0))
	dps *= float(ship.bullet_damage) * float(ship.damage_mult)
	if Ships.BASE_FIRE_COOLDOWN > 0.0:
		dps *= Ships.BASE_FIRE_COOLDOWN / maxf(float(ship.fire_cooldown), Ships.MIN_FIRE_COOLDOWN)
	if float(ship.get("rapid_time")) > 0.0 or float(ship.get("energy_time")) > 0.0:
		dps *= 1.75
	var melt := 0.7 * float(ship.damage_mult) if level >= 3 else 0.0
	_laser.fire(delta, origin, half_w, dps, level >= 2, melt, level >= 3)


func _shoot_homing(origin: Vector2) -> void:
	match ship.weapon_level:
		1:
			for i in 2:
				var dir := Vector2((-0.28 if i == 0 else 0.28), -1.0).normalized()
				ship.projectile_pool.spawn_player(origin, dir * 260.0, 1.35 * ship.damage_mult, {
					"homing": 7.0, "scale": 1.25, "color": Color(0.35, 1.0, 0.45), "lifetime": 3.0})
		2:
			for i in 4:
				var dir := Vector2((i - 1.5) * 0.28, -1.0).normalized()
				ship.projectile_pool.spawn_player(origin, dir * 420.0, 0.95 * ship.damage_mult, {
					"homing": 12.0, "scale": 0.8, "color": Color(0.45, 1.0, 0.55), "lifetime": 2.4})
		_:
			for i in 6:
				var dir := Vector2((i - 2.5) * 0.22, -1.0).normalized()
				ship.projectile_pool.spawn_player(origin, dir * 400.0, 1.05 * ship.damage_mult, {
					"homing": 14.0,
					"scale": 0.95,
					"color": Color(0.3, 1.0, 0.5),
					"lifetime": 2.6,
					"splash_radius": 42.0,
					"splash_damage": 0.7 * ship.damage_mult})
	AudioBus.play_shoot(600.0)