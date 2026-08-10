extends Control
## Title screen.

@onready var campaign_btn: Button = $Center/VBox/CampaignButton
@onready var endless_btn: Button = $Center/VBox/EndlessButton
@onready var practice_btn: Button = $Center/VBox/PracticeButton
@onready var boss_rush_btn: Button = $Center/VBox/BossRushButton
@onready var records_btn: Button = $Center/VBox/RecordsButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var quit_btn: Button = $Center/VBox/QuitButton
@onready var high_score: Label = $Center/VBox/HighScore
@onready var title: Label = $Center/VBox/Title


func _ready() -> void:
	campaign_btn.pressed.connect(_on_campaign)
	endless_btn.pressed.connect(_on_endless)
	practice_btn.pressed.connect(_on_practice)
	boss_rush_btn.pressed.connect(_on_boss_rush)
	records_btn.pressed.connect(_on_records)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	var boss_rush_locked := not GameState.is_sector_unlocked(GameState.SECTOR_2)
	boss_rush_btn.disabled = boss_rush_locked
	if boss_rush_locked:
		boss_rush_btn.text = "Boss Rush  (clear Sector 2)"
	high_score.text = "ENDLESS BEST  %06d\nRAID BEST  %06d" % [GameState.endless_high_score, GameState.boss_rush_high_score]
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


func _on_endless() -> void:
	AudioBus.play_ui()
	GameState.start_endless()
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_practice() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/practice_select.tscn")


func _on_boss_rush() -> void:
	if not GameState.is_sector_unlocked(GameState.SECTOR_2):
		return
	AudioBus.play_ui()
	GameState.start_boss_rush()
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_records() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/records.tscn")


func _on_settings() -> void:
	AudioBus.play_ui()
	GameState.settings_return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
