extends SceneTree
## Renders the parallax backdrop to a PNG for visual review.
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 \
##        --script res://tools/capture_background.gd -- <style> <out.png> [warmup_s]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var style := StringName(args[0]) if args.size() > 0 else &"city"
	var out := args[1] if args.size() > 1 else "user://bg.png"
	var warmup := float(args[2]) if args.size() > 2 else 6.0

	root.size = Vector2i(480, 720)
	var bg_script: Script = load("res://scripts/game/parallax_bg.gd")
	var bg := Node2D.new()
	bg.set_script(bg_script)
	root.add_child(bg)
	await process_frame
	bg.tint = Color(0.2, 0.35, 0.65)
	bg.scroll_speed = 60.0
	bg.set_terrain(style)

	var t := 0.0
	while t < warmup:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(out)
	print("capture style=%s -> %s (%s)" % [style, out, err])
	quit(0)
