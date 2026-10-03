extends SceneTree
## Run one campaign mission headlessly and write a runtime balance report.
##
## Examples:
##   godot --headless --path . --script res://tools/report_balance.gd
##   godot --headless --path . --script res://tools/report_balance.gd -- \
##     --mission 5 --output docs/balance_reports/mission_06.json

const DEFAULT_SAMPLE_SECONDS := 60.0

var _mission_index := 0
var _output_path := ""
var _sample_seconds := DEFAULT_SAMPLE_SECONDS


func _init() -> void:
	_parse_args()
	call_deferred("_run")


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--mission" and i + 1 < args.size():
			_mission_index = clampi(int(args[i + 1]), 0, 9)
		elif args[i] == "--output" and i + 1 < args.size():
			_output_path = args[i + 1]
		elif args[i] == "--duration" and i + 1 < args.size():
			_sample_seconds = clampf(float(args[i + 1]), 5.0, 600.0)
	if _output_path == "":
		_output_path = "user://balance_report_%02d.json" % (_mission_index + 1)


func _run() -> void:
	await process_frame
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	game_state.start_campaign_mission(_mission_index)
	var err := change_scene_to_file("res://scenes/game/game_world.tscn")
	if err != OK:
		push_error("Could not load game world: %s" % err)
		quit(1)
		return
	await process_frame

	var world := current_scene
	var runner: Node = world.find_child("MissionRunner", true, false) if world else null
	var tracker: Node = world.find_child("BalanceTracker", true, false) if world else null
	if runner == null or tracker == null:
		push_error("BalanceTracker or MissionRunner missing from game world")
		quit(1)
		return

	var waited := 0.0
	while not bool(tracker.call("has_finished")) and waited < _sample_seconds:
		await process_frame
		waited += 1.0 / 60.0

	var report: Dictionary = tracker.get_report()
	var completed := bool(tracker.call("has_finished"))
	report["timed_out"] = not completed
	report["sample_duration_limit"] = _sample_seconds
	report["won"] = bool(report.get("won", false)) if completed else false
	if not _write_report(report):
		quit(1)
		return
	print("BALANCE REPORT ", _output_path)
	print(JSON.stringify(report))
	quit(0)


func _write_report(report: Dictionary) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(_output_path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write balance report: %s" % _output_path)
		return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	return true
