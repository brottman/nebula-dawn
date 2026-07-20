extends Control
## Title screen.

@onready var campaign_btn: Button = $Center/VBox/CampaignButton
@onready var endless_btn: Button = $Center/VBox/EndlessButton
@onready var quit_btn: Button = $Center/VBox/QuitButton
@onready var high_score: Label = $Center/VBox/HighScore


func _ready() -> void:
	campaign_btn.pressed.connect(_on_campaign)
	endless_btn.pressed.connect(_on_endless)
	quit_btn.pressed.connect(_on_quit)
	high_score.text = "ENDLESS BEST  %06d" % GameState.endless_high_score
	campaign_btn.grab_focus()
	AudioBus.play_menu_music()


func _on_campaign() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/campaign_select.tscn")


func _on_endless() -> void:
	AudioBus.play_ui()
	GameState.start_endless()
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_quit() -> void:
	get_tree().quit()
