extends SceneTree
## Smoke-test boss rush mode briefly (first boss spawns after the intro card).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.call("start_boss_rush")
	change_scene_to_file("res://scenes/game/game_world.tscn")
	await create_timer(4.0).timeout
	var boss_count: int = get_nodes_in_group("boss").size()
	if boss_count < 1:
		push_error("Boss Rush: no boss spawned")
		quit(1)
		return
	# The boss must be firing through BossPatterns within a few seconds.
	var shots: int = get_nodes_in_group("enemy_projectiles").size()
	if shots < 1:
		push_error("Boss Rush: boss never fired")
		quit(1)
		return
	print("BOSS RUSH SMOKE OK bosses=", boss_count, " shots=", shots)
	quit(0)
