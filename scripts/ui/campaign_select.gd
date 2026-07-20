extends Control
## Pick an unlocked campaign mission.

const TITLES := [
	"1 — Dawn Patrol",
	"2 — Debris Field",
	"3 — Nebula Core",
]

@onready var list: VBoxContainer = $Center/VBox/MissionList
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	for i in TITLES.size():
		var btn := Button.new()
		btn.text = TITLES[i]
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


func _start(index: int) -> void:
	AudioBus.play_ui()
	GameState.start_campaign_mission(index)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
