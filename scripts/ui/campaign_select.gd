extends Control
## Pick an unlocked campaign mission. Buttons are built from GameState.MISSION_PATHS,
## reading each MissionData resource for its display title.

@onready var list: VBoxContainer = $Center/VBox/MissionList
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	AudioBus.play_menu_music()
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
	var data: MissionData = load(GameState.MISSION_PATHS[index])
	if data:
		return "%d — %s" % [index + 1, data.title]
	return "Mission %d" % (index + 1)


func _start(index: int) -> void:
	AudioBus.play_ui()
	GameState.start_campaign_mission(index)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
