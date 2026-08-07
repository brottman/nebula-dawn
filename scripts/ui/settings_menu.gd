extends Control
## Music / SFX / touch sensitivity settings.

@onready var music_slider: HSlider = $Center/VBox/MusicRow/Slider
@onready var sfx_slider: HSlider = $Center/VBox/SfxRow/Slider
@onready var touch_slider: HSlider = $Center/VBox/TouchRow/Slider
@onready var shake_slider: HSlider = $Center/VBox/ShakeRow/Slider
@onready var flash_toggle: CheckButton = $Center/VBox/FlashRow
@onready var labels_toggle: CheckButton = $Center/VBox/LabelsRow
@onready var music_value: Label = $Center/VBox/MusicRow/Value
@onready var sfx_value: Label = $Center/VBox/SfxRow/Value
@onready var touch_value: Label = $Center/VBox/TouchRow/Value
@onready var shake_value: Label = $Center/VBox/ShakeRow/Value
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
	shake_slider.min_value = 0.0
	shake_slider.max_value = 1.0
	shake_slider.step = 0.25
	music_slider.value = GameState.music_volume
	sfx_slider.value = GameState.sfx_volume
	touch_slider.value = GameState.touch_sensitivity
	shake_slider.value = GameState.shake_intensity
	flash_toggle.button_pressed = GameState.reduce_flashes
	labels_toggle.button_pressed = GameState.show_pickup_labels
	_refresh_labels()
	music_slider.value_changed.connect(_on_music)
	sfx_slider.value_changed.connect(_on_sfx)
	touch_slider.value_changed.connect(_on_touch)
	shake_slider.value_changed.connect(_on_shake)
	flash_toggle.toggled.connect(_on_flash_toggled)
	labels_toggle.toggled.connect(_on_labels_toggled)
	back_btn.pressed.connect(_on_back)
	back_btn.grab_focus()
	AudioBus.play_menu_music()


func _refresh_labels() -> void:
	music_value.text = "%d%%" % int(round(GameState.music_volume * 100.0))
	sfx_value.text = "%d%%" % int(round(GameState.sfx_volume * 100.0))
	touch_value.text = "%.2fx" % GameState.touch_sensitivity
	shake_value.text = "%d%%" % int(round(GameState.shake_intensity * 100.0))


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


func _on_shake(v: float) -> void:
	GameState.set_shake_intensity(v)
	_refresh_labels()


func _on_flash_toggled(enabled: bool) -> void:
	GameState.set_reduce_flashes(enabled)
	AudioBus.play_ui()


func _on_labels_toggled(enabled: bool) -> void:
	GameState.set_show_pickup_labels(enabled)
	AudioBus.play_ui()


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file(_return_scene)