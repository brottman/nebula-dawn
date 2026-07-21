extends Control
## Win / lose summary after a run.

@onready var title: Label = $Center/VBox/Title
@onready var score: Label = $Center/VBox/Score
@onready var detail: Label = $Center/VBox/Detail
@onready var again_btn: Button = $Center/VBox/AgainButton
@onready var campaign_btn: Button = $Center/VBox/CampaignButton
@onready var menu_btn: Button = $Center/VBox/MenuButton


func _ready() -> void:
	again_btn.pressed.connect(_on_again)
	campaign_btn.pressed.connect(_on_campaign)
	menu_btn.pressed.connect(_on_menu)
	_populate()
	again_btn.grab_focus()
	AudioBus.play_menu_music()


func _populate() -> void:
	if GameState.mode == GameState.Mode.ENDLESS:
		title.text = "RUN OVER"
		detail.text = "High score  %06d" % GameState.endless_high_score
		campaign_btn.text = "Sector Select"
	elif GameState.last_won:
		if GameState.is_sector_finale():
			title.text = "SECTOR 1 CLEARED"
			detail.text = "Flagship Core destroyed"
		else:
			title.text = "STAGE CLEARED"
			detail.text = "%s complete" % GameState.stage_code()
		campaign_btn.text = "Sector 1"
	else:
		title.text = "SHIP DESTROYED"
		detail.text = "Try again, pilot — %s" % GameState.stage_code()
		campaign_btn.text = "Sector 1"
	score.text = "SCORE  %06d" % GameState.last_score


func _on_again() -> void:
	AudioBus.play_ui()
	if GameState.mode == GameState.Mode.ENDLESS:
		GameState.start_endless()
	else:
		GameState.start_campaign_mission(GameState.current_mission_index)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_campaign() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/campaign_select.tscn")


func _on_menu() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
