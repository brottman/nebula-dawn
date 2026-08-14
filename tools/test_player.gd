extends SceneTree
## Instantiate the player facade and exercise WeaponSystem / LifeSystem.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null or not gs.has_method("reset_hangar"):
		push_error("GameState.reset_hangar missing")
		quit(1)
		return
	gs.call("reset_hangar")
	gs.call("start_campaign_mission", 0)
	var packed: PackedScene = load("res://scenes/entities/player.tscn")
	if packed == null:
		push_error("player.tscn missing")
		quit(1)
		return
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame

	if player.get("weapons") == null or player.get("life") == null:
		push_error("WeaponSystem / LifeSystem not bound")
		quit(1)
		return
	if int(player.lives) != 3:
		push_error("expected 3 lives, got %s" % player.lives)
		quit(1)
		return

	player.call("apply_pickup", "spread")
	if int(player.weapon) != 1:
		push_error("spread pickup did not select Spread")
		quit(1)
		return
	for _i in 5:
		player.call("apply_pickup", "pchip")
	if int(player.weapon_level) != 2:
		push_error("5 Power pickups should reach Lv2, got %s" % player.weapon_level)
		quit(1)
		return

	player.call("take_damage", 1)
	if int(player.weapon) != 0:
		push_error("hull hit should reset to Blaster")
		quit(1)
		return

	player.call("apply_pickup", "bomb")
	if int(player.bomb_stock) != 1:
		push_error("bomb pickup failed")
		quit(1)
		return
	if not bool(player.call("try_use_bomb")):
		push_error("try_use_bomb returned false")
		quit(1)
		return
	if int(player.bomb_stock) != 0:
		push_error("bomb stock not consumed")
		quit(1)
		return

	player.call("apply_pickup", "shield")
	if int(player.shield_charges) < 1:
		push_error("shield pickup failed")
		quit(1)
		return

	player.call("apply_pickup", "laser")
	if int(player.weapon) != 2:
		push_error("laser pickup did not select Laser")
		quit(1)
		return
	player.global_position = Vector2(240, 500)
	var enemy_scene: PackedScene = load("res://scenes/entities/enemy_base.tscn")
	var stats: Resource = load("res://resources/enemies/drone.tres")
	if enemy_scene == null or stats == null:
		push_error("laser test missing enemy scene or drone stats")
		quit(1)
		return
	var enemy: Node = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.call("setup", stats, null, 0.0)
	enemy.global_position = Vector2(240, 220)
	await process_frame
	var hp_before := float(enemy.get("hp"))
	player.get("weapons").call("tick_fire", 0.1)
	if float(enemy.get("hp")) >= hp_before:
		push_error("laser beam did not damage a target in column")
		quit(1)
		return
	var beam: Node = player.get_node_or_null("LaserBeam")
	if beam == null or not bool(beam.visible):
		push_error("laser beam visual missing or hidden while firing")
		quit(1)
		return
	enemy.queue_free()

	print("PLAYER API OK lives=", player.lives, " hp=", player.hp)
	player.queue_free()
	quit(0)