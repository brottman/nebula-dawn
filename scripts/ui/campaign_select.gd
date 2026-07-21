extends Control
## Pick an unlocked Sector 1 stage. Buttons are built from GameState.MISSION_PATHS.

@onready var title_label: Label = $Center/VBox/Title
@onready var subtitle_label: Label = $Center/VBox/Subtitle
@onready var list: VBoxContainer = $Center/VBox/MissionList
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	AudioBus.play_menu_music()
	title_label.text = "SECTOR 1"
	subtitle_label.text = "Five stages to the Flagship Core"
	for i in GameState.MISSION_PATHS.size():
		var btn := Button.new()
		btn.text = _mission_title(i)
		btn.custom_minimum_size = Vector2(280, 44)
		var unlocked := GameState.is_mission_unlocked(i)
		btn.disabled = not unlocked
		if not unlocked:
			btn.text += "  (locked)"
		var idx := i
		btn.pressed.connect(func() -> void: _start(idx))
		list.add_child(btn)
		if i == 0:
			btn.grab_focus()


func _mission_title(index: int) -> String:
	var data: MissionData = GameState.get_mission_data(index)
	if data:
		return "%d-%d  %s" % [data.sector, data.stage, data.title]
	return "1-%d  Stage %d" % [index + 1, index + 1]


func _start(index: int) -> void:
	AudioBus.play_ui()
	GameState.start_campaign_mission(index)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
