extends SceneTree
## Smoke-test endless mode briefly.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.call("start_endless")
	change_scene_to_file("res://scenes/game/game_world.tscn")
	await create_timer(2.0).timeout
	print("ENDLESS SMOKE OK")
	quit(0)
