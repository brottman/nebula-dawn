extends SceneTree
## Instantiate the player facade and exercise WeaponSystem / LifeSystem.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
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
		push_error("5 P-Chips should reach Lv2, got %s" % player.weapon_level)
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

	print("PLAYER API OK lives=", player.lives, " hp=", player.hp)
	player.queue_free()
	quit(0)
