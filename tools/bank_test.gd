extends Node
## Headless test: simulate touch drag right, verify banking + drones.

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/entities/player.tscn")
	var player: Node = scene.instantiate()
	add_child(player)
	player.global_position = Vector2(240, 500)
	player._touch_active = true
	player._touch_world = Vector2(240, 500)
	player._touch_grab_offset = player.global_position - player._touch_world
	for i in 25:
		player._touch_world = Vector2(240.0 + 180.0 * minf(float(i) / 10.0, 1.0), 500.0)
		player._physics_process(0.0167)
		var vis: CanvasItem = player._visual()
		print("frame %02d x=%6.1f vx=%7.1f bank=%+.3f rot=%+.3f" % [
			i, player.global_position.x, player.bank_vx, player._bank, vis.rotation])
	player._touch_active = false
	for i in 20:
		player._physics_process(0.0167)
		print("stop  %02d x=%6.1f vx=%7.1f bank=%+.3f rot=%+.3f" % [
			i, player.global_position.x, player.bank_vx, player._bank, player._visual().rotation])
	player.weapons.add_drone()
	player.weapons.add_drone()
	player.weapons.add_drone()
	print("drone_count=", player.drone_count)
	await get_tree().create_timer(0.6).timeout
	var idx := 0
	for c in player.get_children():
		if c is Drone:
			var d := c as Drone
			print("drone %d slot=%d pos=%s vis=%s sprite=%s rot=%.3f" % [
				idx, d.slot, str(d.global_position), d.visible, str(d._sprite != null), d.rotation])
			idx += 1
	get_tree().quit()
