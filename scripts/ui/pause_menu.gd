extends CanvasLayer
## Pause overlay (process always so it works while tree paused).

@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBox/ResumeButton
@onready var settings_btn: Button = $Root/Panel/VBox/SettingsButton
@onready var menu_btn: Button = $Root/Panel/VBox/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_on_resume)
	settings_btn.pressed.connect(_on_settings)
	menu_btn.pressed.connect(_on_menu)
	hide_menu()


func show_menu() -> void:
	Engine.time_scale = 1.0
	root.visible = true
	resume_btn.grab_focus()


func hide_menu() -> void:
	root.visible = false


func _on_resume() -> void:
	AudioBus.play_ui()
	get_tree().paused = false
	hide_menu()


func _on_settings() -> void:
	AudioBus.play_ui()
	get_tree().paused = false
	hide_menu()
	GameState.settings_return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_menu() -> void:
	AudioBus.play_ui()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
