extends Control
## Music / SFX / touch sensitivity settings.

@onready var music_slider: HSlider = $Center/VBox/MusicRow/Slider
@onready var sfx_slider: HSlider = $Center/VBox/SfxRow/Slider
@onready var touch_slider: HSlider = $Center/VBox/TouchRow/Slider
@onready var music_value: Label = $Center/VBox/MusicRow/Value
@onready var sfx_value: Label = $Center/VBox/SfxRow/Value
@onready var touch_value: Label = $Center/VBox/TouchRow/Value
@onready var back_btn: Button = $Center/VBox/BackButton

var _return_scene: String = "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_return_scene = GameState.settings_return_scene if GameState.settings_return_scene != "" else "res://scenes/ui/main_menu.tscn"
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	touch_slider.min_value = 0.5
	touch_slider.max_value = 1.5
	touch_slider.step = 0.05
	music_slider.value = GameState.music_volume
	sfx_slider.value = GameState.sfx_volume
	touch_slider.value = GameState.touch_sensitivity
	_refresh_labels()
	music_slider.value_changed.connect(_on_music)
	sfx_slider.value_changed.connect(_on_sfx)
	touch_slider.value_changed.connect(_on_touch)
	back_btn.pressed.connect(_on_back)
	back_btn.grab_focus()
	AudioBus.play_menu_music()


func _refresh_labels() -> void:
	music_value.text = "%d%%" % int(round(GameState.music_volume * 100.0))
	sfx_value.text = "%d%%" % int(round(GameState.sfx_volume * 100.0))
	touch_value.text = "%.2fx" % GameState.touch_sensitivity


func _on_music(v: float) -> void:
	GameState.set_music_volume(v)
	_refresh_labels()


func _on_sfx(v: float) -> void:
	GameState.set_sfx_volume(v)
	_refresh_labels()
	AudioBus.play_ui()


func _on_touch(v: float) -> void:
	GameState.set_touch_sensitivity(v)
	_refresh_labels()


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file(_return_scene)
