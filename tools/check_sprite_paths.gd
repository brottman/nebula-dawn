extends SceneTree
## Checks sprite-path resolution the way the shipped build sees it. Run from the
## project, then again against an exported pack, to confirm that
## ResourceLoader.exists() works where FileAccess.file_exists() does not.
##   godot --headless --path . --script res://tools/check_sprite_paths.gd
##   godot --headless --main-pack <pack>.pck --script res://tools/check_sprite_paths.gd

const PATHS := [
	"res://assets/sprites/enemy_asteroid.svg",
	"res://assets/sprites/enemy_scout.svg",
	"res://assets/sprites/enemy_boss_tempest.svg",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := OS.has_feature("editor") == false
	print("context: ", "editor" if not packed else "packed/export")
	for p in PATHS:
		print("  %-46s FileAccess=%-5s ResourceLoader=%s" % [
			p, str(FileAccess.file_exists(p)), str(ResourceLoader.exists(p))])
	print("DONE")
	quit(0)
