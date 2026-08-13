extends CanvasLayer
## Pause overlay (process always so it works while tree paused).
## Settings opens as a child overlay so the run is not unloaded.

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBox/ResumeButton
@onready var settings_btn: Button = $Root/Panel/VBox/SettingsButton
@onready var menu_btn: Button = $Root/Panel/VBox/MenuButton

var _settings: Control


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
	_free_settings()
	root.visible = false


func is_settings_open() -> bool:
	return _settings != null and is_instance_valid(_settings)


## Close the settings overlay and return to the pause panel (run stays paused).
func close_settings() -> void:
	if not is_settings_open():
		return
	_free_settings()
	if get_tree().paused:
		root.visible = true
		resume_btn.grab_focus()


func _free_settings() -> void:
	if _settings == null:
		return
	var inst := _settings
	_settings = null
	if is_instance_valid(inst):
		if inst.has_signal("closed") and inst.is_connected("closed", _on_settings_closed):
			inst.disconnect("closed", _on_settings_closed)
		inst.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not (event.is_action("pause") or event.is_action("ui_cancel")):
		return
	if is_settings_open():
		AudioBus.play_ui()
		close_settings()
		get_viewport().set_input_as_handled()
	elif root.visible:
		_on_resume()
		get_viewport().set_input_as_handled()


func _on_resume() -> void:
	AudioBus.play_ui()
	get_tree().paused = false
	hide_menu()


func _on_settings() -> void:
	AudioBus.play_ui()
	if is_settings_open():
		return
	var inst := SETTINGS_SCENE.instantiate() as Control
	inst.set("overlay_mode", true)
	inst.process_mode = Node.PROCESS_MODE_ALWAYS
	inst.connect("closed", _on_settings_closed)
	_settings = inst
	root.visible = false
	add_child(inst)


func _on_settings_closed() -> void:
	_settings = null
	if get_tree() != null and get_tree().paused:
		root.visible = true
		resume_btn.grab_focus()


func _on_menu() -> void:
	AudioBus.play_ui()
	Engine.time_scale = 1.0
	_free_settings()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
