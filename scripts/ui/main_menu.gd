extends Control
## Title screen.

const Ships := preload("res://scripts/hangar/ship_catalog.gd")
const APP_VERSION := "v0.14.3"

@onready var campaign_btn: Button = $Center/VBox/CampaignButton
@onready var hangar_btn: Button = $Center/VBox/HangarButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var quit_btn: Button = $Center/VBox/QuitButton
@onready var credits_label: Label = $Center/VBox/Credits
@onready var title: Label = $Center/VBox/Title
@onready var version_label: Label = $Version


func _ready() -> void:
	campaign_btn.pressed.connect(_on_campaign)
	hangar_btn.pressed.connect(_on_hangar)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	credits_label.text = "CREDITS  %s    ·    %s" % [
		Ships.format_credits(GameState.credits),
		GameState.equipped_ship_name(),
	]
	if version_label:
		version_label.text = APP_VERSION
	campaign_btn.grab_focus()
	AudioBus.play_menu_music()
	AudioBus.apply_volumes()
	_animate_title()


## Gentle breathing so the title feels alive behind the attract backdrop.
func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(title, "modulate:a", 0.8, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "modulate:a", 1.0, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_campaign() -> void:
	AudioBus.play_ui()
	GameState.settings_return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/campaign_select.tscn")


func _on_hangar() -> void:
	AudioBus.play_ui()
	GameState.hangar_return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/hangar.tscn")


func _on_settings() -> void:
	AudioBus.play_ui()
	GameState.settings_return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()