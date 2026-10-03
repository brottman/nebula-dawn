extends SceneTree
## Boots GameWorld for 1-1 and 2-1 briefly to catch runtime errors.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	if not await _boot_mission(gs, 0, "1-1"):
		return
	if not await _boot_mission(gs, 5, "2-1"):
		return
	print("RUNTIME SMOKE OK")
	quit(0)


func _boot_mission(gs: Node, index: int, code: String) -> bool:
	gs.call("start_campaign_mission", index)
	var err := change_scene_to_file("res://scenes/game/game_world.tscn")
	if err != OK:
		push_error("change_scene failed (%s): %s" % [code, err])
		quit(1)
		return false
	## Stage intro card holds ~2s before waves start; wait past it.
	await create_timer(4.0).timeout
	print("RUNTIME SMOKE ", code, " score=", gs.get("session_score"))
	var world := current_scene
	if world == null:
		push_error("No current scene after %s" % code)
		quit(1)
		return false
	var director := world.find_child("StageDirector", true, false)
	if director == null or director.get_child_count() < 1:
		push_error("StageDirector did not load a gimmick for %s" % code)
		quit(1)
		return false
	return true
