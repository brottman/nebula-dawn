extends SceneTree
## Boots GameWorld in campaign mode briefly to catch runtime errors.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	gs.call("start_campaign_mission", 0)
	var err := change_scene_to_file("res://scenes/game/game_world.tscn")
	if err != OK:
		push_error("change_scene failed: %s" % err)
		quit(1)
		return
	## Stage intro card holds ~2s before waves start; wait past it.
	await create_timer(4.0).timeout
	print("RUNTIME SMOKE OK score=", gs.get("session_score"))
	quit(0)
