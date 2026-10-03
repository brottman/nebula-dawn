extends SceneTree
## Boots a real campaign mission and renders a frame to PNG so the backdrop can
## be checked behind live gameplay (player, enemies, bullets, HUD).
## Run under weston + godot --display-driver wayland --rendering-driver opengl3:
##   godot --path . --display-driver wayland --rendering-driver opengl3 \
##     --script res://tools/capture_game.gd -- <mission_index> <out.png> [wait_s]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		push_error("capture_game: GameState missing")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) if args.size() > 0 else 0
	var out := args[1] if args.size() > 1 else "/tmp/opencode/game.png"
	var wait_s := float(args[2]) if args.size() > 2 else 9.0

	gs.call("start_campaign_mission", index)
	var err := change_scene_to_file("res://scenes/game/game_world.tscn")
	if err != OK:
		push_error("capture_game: change_scene failed %s" % err)
		quit(1)
		return

	var t := 0.0
	while t < wait_s:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var serr := img.save_png(out)
	print("game capture mission=%d -> %s (%s)" % [index, out, serr])
	quit(0)
