extends SceneTree
## Smoke-test endless mode briefly.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.call("start_endless")
	change_scene_to_file("res://scenes/game/game_world.tscn")
	## Stage intro card holds ~2s before waves start; wait past it.
	await create_timer(3.5).timeout
	print("ENDLESS SMOKE OK")
	quit(0)
