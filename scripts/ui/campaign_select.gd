extends Control
## Campaign stage list for both sectors, with best-rank badges.

const Ships := preload("res://scripts/hangar/ship_catalog.gd")

@onready var title_label: Label = $Center/VBox/Title
@onready var subtitle_label: Label = $Center/VBox/Subtitle
@onready var hangar_status: Label = $Center/VBox/HangarStatus
@onready var list: VBoxContainer = $Center/VBox/Scroll/MissionList
@onready var hangar_btn: Button = $Center/VBox/HangarButton
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	hangar_btn.pressed.connect(_on_hangar)
	AudioBus.play_menu_music()
	title_label.text = "CAMPAIGN"
	subtitle_label.text = "Sector 1 + Sector 2"
	hangar_status.text = "Equipped  %s    ·    %s cr" % [
		GameState.equipped_ship_name(),
		Ships.format_credits(GameState.credits),
	]
	_build_list()


func _build_list() -> void:
	for child in list.get_children():
		child.queue_free()
	var focused := false
	_add_header("SECTOR 1 — To the Flagship Core")
	for i in GameState.SECTOR_1_COUNT:
		focused = _add_mission_button(i, focused) or focused
	_add_header("SECTOR 2 — Beyond the Dawn Gate")
	var s2_unlocked := GameState.is_sector_unlocked(GameState.SECTOR_2)
	if not s2_unlocked:
		var lock := Label.new()
		lock.text = "Clear Flagship Core to unlock"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 12)
		lock.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
		list.add_child(lock)
	for i in range(GameState.SECTOR_1_COUNT, GameState.MISSION_PATHS.size()):
		focused = _add_mission_button(i, focused) or focused
	if not focused:
		back_btn.grab_focus()


func _add_header(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
	list.add_child(h)


func _add_mission_button(index: int, already_focused: bool) -> bool:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 44)
	var unlocked := GameState.is_mission_unlocked(index)
	btn.disabled = not unlocked
	btn.text = _mission_title(index)
	if not unlocked:
		btn.text += "  (locked)"
	else:
		var rank := GameState.get_best_rank(index)
		if rank != "":
			btn.text += "   [%s]" % rank
	var idx := index
	btn.pressed.connect(func() -> void: _start(idx))
	list.add_child(btn)
	if unlocked and not already_focused:
		btn.grab_focus()
		return true
	return false


func _mission_title(index: int) -> String:
	var data: MissionData = GameState.get_mission_data(index)
	if data:
		return "%d-%d  %s" % [data.sector, data.stage, data.title]
	return GameState.stage_code(index)


func _start(index: int) -> void:
	AudioBus.play_ui()
	GameState.start_campaign_mission(index)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_hangar() -> void:
	AudioBus.play_ui()
	GameState.hangar_return_scene = "res://scenes/ui/campaign_select.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/hangar.tscn")


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")