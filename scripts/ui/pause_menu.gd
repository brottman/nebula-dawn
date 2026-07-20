extends CanvasLayer
## Pause overlay (process always so it works while tree paused).

@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBox/ResumeButton
@onready var menu_btn: Button = $Root/Panel/VBox/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_on_resume)
	menu_btn.pressed.connect(_on_menu)
	hide_menu()


func show_menu() -> void:
	root.visible = true
	resume_btn.grab_focus()


func hide_menu() -> void:
	root.visible = false


func _on_resume() -> void:
	AudioBus.play_ui()
	get_tree().paused = false
	hide_menu()


func _on_menu() -> void:
	AudioBus.play_ui()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
