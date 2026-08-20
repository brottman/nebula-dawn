class_name LifeSystem
extends Node
## Hull, lives, shields, bombs, death/respawn, Overdrive, and zone status.
## Public ship API still lives on the player; this node owns survival logic.

const CHIPS_PER_LEVEL := 1
const MAX_SHIELD_CHARGES := 2
const MAX_BOMB_STOCK := 3
const START_LIVES := 3
const DEATH_BOMB_WINDOW := 0.25
const RESPAWN_INVULN := 2.5
const OVERDRIVE_MAX := 100.0

var ship: CharacterBody2D


func bind(host: CharacterBody2D) -> void:
	ship = host


func reset_run() -> void:
	var spec: Dictionary = GameState.get_active_loadout()
	ship.hp = ship.max_hp
	ship.lives = int(spec.get("lives", START_LIVES))
	ship.bomb_stock = mini(MAX_BOMB_STOCK, int(spec.get("start_bombs", 0)))
	ship.shield_charges = mini(MAX_SHIELD_CHARGES, int(spec.get("start_shields", 0)))
	ship.dead = false
	ship._respawning = false
	ship._death_bomb_time = 0.0
	ship._update_shield_visuals()


func update_timers(delta: float) -> void:
	if ship.invuln_time > 0.0:
		ship.invuln_time -= delta
	ship._update_shield_visuals()
	if ship.rapid_time > 0.0:
		ship.rapid_time -= delta
	if ship.overdrive_time > 0.0:
		ship.overdrive_time -= delta
		if ship.overdrive_time <= 0.0:
			Engine.time_scale = 1.0
			EventBus.gimmick_toast.emit("OVERDRIVE END")


func tick_death_bomb(delta: float) -> bool:
	## Returns true if this frame consumed the physics tick (dying or saved).
	ship._death_bomb_time -= delta
	if Input.is_action_just_pressed("bomb"):
		try_death_bomb()
		return true
	if ship._death_bomb_time <= 0.0:
		confirm_death()
	return true


func enter_plasma() -> void:
	ship.plasma_active = true
	ship.damage_mult = 1.5
	ship.secondaries_disabled = true
	EventBus.gimmick_toast.emit("PLASMA BOOST")


func exit_plasma() -> void:
	ship.plasma_active = false
	ship.damage_mult = 1.0
	ship.secondaries_disabled = false


func clear_zone_effects() -> void:
	exit_plasma()
	ship.scrap_push = 0.0
	ship.overdrive_time = 0.0
	Engine.time_scale = 1.0


func add_overdrive(amount: float) -> void:
	if ship.overdrive_time > 0.0:
		return
	ship.overdrive = minf(OVERDRIVE_MAX, ship.overdrive + amount)
	EventBus.overdrive_changed.emit(ship.overdrive, OVERDRIVE_MAX)
	if ship.overdrive >= OVERDRIVE_MAX:
		_activate_overdrive()


func _activate_overdrive() -> void:
	ship.overdrive = 0.0
	EventBus.overdrive_changed.emit(ship.overdrive, OVERDRIVE_MAX)
	ship.overdrive_time = 1.6
	Engine.time_scale = 0.4
	ship.rapid_time = maxf(ship.rapid_time, 1.6)
	EventBus.overdrive_activated.emit()
	EventBus.gimmick_toast.emit("OVERDRIVE")


func restore_full() -> void:
	ship.hp = ship.max_hp
	EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)


func take_damage(amount: int) -> void:
	if ship.dead or ship._cinematic or ship._respawning or ship.invuln_time > 0.0:
		return
	if ship._death_bomb_time > 0.0:
		return
	if ship.shield_charges > 0:
		ship.shield_charges -= 1
		ship._update_shield_visuals()
		ship.invuln_time = 0.75
		AudioBus.play_player_hurt()
		EventBus.screen_shake.emit(4.0, 0.12)
		EventBus.gimmick_toast.emit("SHIELD BREAK" if ship.shield_charges <= 0 else "SHIELD  ×%d" % ship.shield_charges)
		ship.weapons.lose_drone()
		return
	if ship.hp - amount <= 0:
		if ship.bomb_stock > 0:
			ship.hp = 0
			EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)
			ship.weapons.lose_drone()
			ship._death_bomb_time = DEATH_BOMB_WINDOW
			ship.invuln_time = DEATH_BOMB_WINDOW
			EventBus.gimmick_toast.emit("DEATH BOMB!")
			EventBus.screen_shake.emit(6.0, 0.1)
			return
		ship.hp = 0
		EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)
		confirm_death()
		return
	ship.hp = maxi(0, ship.hp - amount)
	ship.weapons.lose_drone()
	ship.invuln_time = 1.35
	ship._flash_timer = 0.2
	EventBus.player_hull_hit.emit()
	AudioBus.play_player_hurt()
	EventBus.screen_shake.emit(8.0, 0.18)
	EventBus.hitstop_requested.emit(0.07)
	EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)


func add_shield(charges: int = 2) -> void:
	ship.shield_charges = mini(MAX_SHIELD_CHARGES, ship.shield_charges + charges)
	ship._update_shield_visuals()
	EventBus.gimmick_toast.emit("SHIELD  ×%d" % ship.shield_charges)


func add_bomb(count: int = 1) -> void:
	ship.bomb_stock = mini(MAX_BOMB_STOCK, ship.bomb_stock + count)
	EventBus.bomb_stock_changed.emit(ship.bomb_stock)
	EventBus.gimmick_toast.emit("BOMB  ×%d" % ship.bomb_stock)


func try_use_bomb() -> bool:
	if ship.dead or ship._cinematic or ship.bomb_stock <= 0:
		return false
	ship.bomb_stock -= 1
	EventBus.bomb_stock_changed.emit(ship.bomb_stock)
	activate_bomb()
	ship.invuln_time = maxf(ship.invuln_time, 0.85)
	return true


func try_death_bomb() -> void:
	if ship._death_bomb_time <= 0.0 or ship.bomb_stock <= 0:
		return
	ship._death_bomb_time = 0.0
	ship.bomb_stock -= 1
	EventBus.bomb_stock_changed.emit(ship.bomb_stock)
	ship.hp = 1
	EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)
	activate_bomb()
	ship.invuln_time = 1.6
	EventBus.gimmick_toast.emit("SAVED!")


func activate_bomb() -> void:
	EventBus.gimmick_toast.emit("BOMB")
	EventBus.screen_shake.emit(10.0, 0.22)
	EventBus.hitstop_requested.emit(0.08)
	AudioBus.play_bomb()
	var vp: Vector2 = ship.get_viewport_rect().size
	var center := vp * 0.5
	var fx_parent := ship.get_parent()
	if fx_parent:
		CombatFX.spawn_ring(fx_parent, ship.global_position, Color(1.0, 0.75, 0.35), 28.0)
		CombatFX.spawn_burst(fx_parent, ship.global_position, Color(1.0, 0.6, 0.25), 16, 48.0)
	if ship.projectile_pool and ship.projectile_pool.has_method("clear_enemy_in_radius"):
		ship.projectile_pool.clear_enemy_in_radius(center, maxf(vp.x, vp.y) * 1.2)
	var tree := ship.get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var is_stage_boss := n.is_in_group("boss") and not n.is_in_group("mid_boss")
		if is_stage_boss:
			n.take_damage(4.0)
		elif n.is_in_group("mid_boss"):
			n.take_damage(12.0)
		else:
			n.take_damage(10.0)
	for n in tree.get_nodes_in_group("hazards"):
		if n != null and is_instance_valid(n) and n.has_method("take_damage"):
			n.take_damage(6.0)


func confirm_death() -> void:
	ship._death_bomb_time = 0.0
	_die()


func _die() -> void:
	if ship.dead or ship._respawning:
		return
	ship.dead = true
	ship._cinematic = false
	ship._touch_active = false
	ship._touch_index = -1
	_spawn_volcano_drop()
	ship.weapons.clear_drones()
	ship.shield_charges = 0
	ship.rapid_time = 0.0
	clear_zone_effects()
	ship.visible = false
	ship.set_physics_process(true)
	AudioBus.play_explode()
	EventBus.screen_shake.emit(12.0, 0.28)
	EventBus.hitstop_requested.emit(0.18)
	var fx_parent := ship.get_parent()
	if fx_parent:
		CombatFX.spawn_ring(fx_parent, ship.global_position, Color(0.55, 0.9, 1.0), 16.0)
		CombatFX.spawn_burst(fx_parent, ship.global_position, Color(0.7, 0.9, 1.0), 14, 34.0)
	ship.lives -= 1
	EventBus.player_lives_changed.emit(ship.lives)
	if ship.lives <= 0:
		EventBus.player_died.emit()
		ship.set_physics_process(false)
		return
	EventBus.gimmick_toast.emit("%d SHIP%s LEFT" % [ship.lives, "S" if ship.lives != 1 else ""])
	_respawn_after_delay()


func _respawn_after_delay() -> void:
	ship._respawning = true
	await ship.get_tree().create_timer(1.05).timeout
	if not ship.is_inside_tree() or ship.lives <= 0:
		ship._respawning = false
		return
	_respawn()


func _respawn() -> void:
	var vp: Vector2 = ship.get_viewport_rect().size
	ship.global_position = Vector2(vp.x * 0.5, vp.y * 0.83)
	ship.dead = false
	ship._respawning = false
	ship.hp = ship.max_hp
	ship.invuln_time = RESPAWN_INVULN
	ship.weapons.restore_on_respawn(GameState.get_power_floor())
	if GameState.is_ex_stage():
		if randf() < 0.5:
			add_bomb(1)
		else:
			add_shield(1)
	ship.visible = true
	ship.scale = Vector2.ONE
	ship._update_shield_visuals()
	var vis: CanvasItem = ship._visual()
	vis.modulate = ship._ship_tint
	EventBus.player_hp_changed.emit(ship.hp, ship.max_hp)
	ship.weapons.emit_changed()
	EventBus.gimmick_toast.emit("RESPAWN  Lv%d" % ship.weapon_level)


func _spawn_volcano_drop() -> void:
	ship.call_deferred("_spawn_volcano_drop_now")


func spawn_volcano_drop_now() -> void:
	if not ship.is_inside_tree():
		return
	var parent := ship.get_parent()
	if parent == null:
		return
	var entities := parent.get_node_or_null("Entities")
	var host: Node = entities if entities else parent
	var scene: PackedScene = load("res://scenes/entities/pickup.tscn")
	if scene == null:
		return
	var floor_lv: int = GameState.get_power_floor()
	var peak_chips: int = (int(ship._life_peak_level) - 1) * CHIPS_PER_LEVEL + int(ship._life_peak_chips)
	var floor_chips: int = (floor_lv - 1) * CHIPS_PER_LEVEL
	var lost: int = maxi(0, peak_chips - floor_chips)
	var restore_pool: int = maxi(2, int(round(float(lost) * randf_range(0.50, 0.75))))
	var count: int = randi_range(3, 4)
	var base: int = int(restore_pool / count)
	var rem: int = restore_pool % count
	for i in count:
		var p: Node = scene.instantiate()
		host.add_child(p)
		var ang := -PI * 0.5 + lerpf(-0.85, 0.85, float(i) / float(maxi(count - 1, 1)))
		var burst := Vector2(cos(ang), sin(ang)) * randf_range(36.0, 68.0)
		p.global_position = ship.global_position + burst
		var chips_here := float(base + (1 if i < rem else 0))
		if p.has_method("set_volcano"):
			p.set_volcano(true)
		if p.has_method("setup"):
			p.setup("power_orb")
		p.orb_restore = maxf(1.0, chips_here)
		p.fall_speed = 38.0