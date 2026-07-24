extends Control
## Mission statistics after a run, with retry / next-mission navigation.

@onready var title: Label = $Scroll/VBox/Title
@onready var mission_name: Label = $Scroll/VBox/MissionName
@onready var subtitle: Label = $Scroll/VBox/Subtitle
@onready var score: Label = $Scroll/VBox/Score
@onready var rank_label: Label = $Scroll/VBox/RankLabel
@onready var rank_detail: Label = $Scroll/VBox/RankDetail
@onready var detail: Label = $Scroll/VBox/Detail
@onready var next_btn: Button = $Scroll/VBox/NextButton
@onready var again_btn: Button = $Scroll/VBox/AgainButton
@onready var campaign_btn: Button = $Scroll/VBox/CampaignButton
@onready var menu_btn: Button = $Scroll/VBox/MenuButton

@onready var stat_time: Label = $Scroll/VBox/StatsPanel/Stats/StatTime/V
@onready var stat_kills: Label = $Scroll/VBox/StatsPanel/Stats/StatKills/V
@onready var stat_hazards: Label = $Scroll/VBox/StatsPanel/Stats/StatHazards/V
@onready var stat_pickups: Label = $Scroll/VBox/StatsPanel/Stats/StatPickups/V
@onready var stat_hits: Label = $Scroll/VBox/StatsPanel/Stats/StatHits/V
@onready var stat_power: Label = $Scroll/VBox/StatsPanel/Stats/StatPower/V
@onready var stat_formations: Label = $Scroll/VBox/StatsPanel/Stats/StatFormations/V
@onready var stat_bosses: Label = $Scroll/VBox/StatsPanel/Stats/StatBosses/V
@onready var formations_row: Control = $Scroll/VBox/StatsPanel/Stats/StatFormations


func _ready() -> void:
	next_btn.pressed.connect(_on_next)
	again_btn.pressed.connect(_on_again)
	campaign_btn.pressed.connect(_on_campaign)
	menu_btn.pressed.connect(_on_menu)
	_populate()
	_focus_primary()
	AudioBus.play_menu_music()


func _populate() -> void:
	_fill_stats()
	_fill_header()
	_configure_buttons()


func _fill_stats() -> void:
	stat_time.text = GameState.format_run_time()
	stat_kills.text = str(GameState.run_kills)
	stat_hazards.text = str(GameState.run_hazards)
	stat_pickups.text = str(GameState.run_pickups)
	stat_hits.text = str(GameState.run_hits_taken)
	stat_power.text = "Lv %d" % GameState.run_max_weapon_level
	stat_formations.text = str(GameState.run_formations)
	stat_bosses.text = str(GameState.run_bosses_defeated)
	# Formations only matter for Stage 1, but showing zeros is fine elsewhere.
	formations_row.visible = GameState.run_formations > 0 or (
		GameState.mode == GameState.Mode.CAMPAIGN and GameState.current_mission_index == 0
	)


func _fill_header() -> void:
	score.text = "SCORE  %06d" % GameState.last_score
	_fill_rank()

	if GameState.mode == GameState.Mode.ENDLESS:
		title.text = "RUN OVER"
		mission_name.text = "ENDLESS"
		subtitle.text = "Survive as long as you can"
		var best := GameState.endless_high_score
		if GameState.last_score >= best and GameState.last_score > 0:
			detail.text = "New high score!"
		else:
			detail.text = "High score  %06d" % best
		return

	var data: MissionData = GameState.get_mission_data()
	var code := GameState.stage_code()
	if data:
		mission_name.text = "%s  %s" % [code, data.title]
		subtitle.text = data.subtitle
	else:
		mission_name.text = code
		subtitle.text = ""

	if GameState.last_won:
		if GameState.is_sector_finale():
			title.text = "SECTOR 1 CLEARED"
			detail.text = "Flagship Core destroyed — Sector 1 complete"
		else:
			title.text = "STAGE CLEARED"
			detail.text = "Stage %s complete" % code
	else:
		title.text = "SHIP DESTROYED"
		detail.text = "Try again, pilot"


func _fill_rank() -> void:
	if rank_label == null:
		return
	var rank := GameState.last_rank
	if rank == "" or not GameState.last_won or GameState.mode != GameState.Mode.CAMPAIGN:
		rank_label.visible = false
		if rank_detail:
			rank_detail.visible = false
		return
	rank_label.visible = true
	rank_label.text = "RANK  %s" % rank
	match rank:
		"S":
			rank_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		"A":
			rank_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75))
		"B":
			rank_label.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
		_:
			rank_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	if rank_detail:
		rank_detail.visible = true
		var bonus := GameState.last_rank_bonus
		rank_detail.text = "Clear bonus  +%d" % bonus if bonus > 0 else ""


func _configure_buttons() -> void:
	if GameState.mode == GameState.Mode.ENDLESS:
		next_btn.visible = false
		again_btn.text = "Play Again"
		campaign_btn.text = "Sector Select"
		return

	campaign_btn.text = "Sector Select"
	again_btn.text = "Retry Mission"

	if GameState.has_next_mission():
		next_btn.visible = true
		var nxt := GameState.next_mission_index()
		var next_data: MissionData = GameState.get_mission_data(nxt)
		if next_data:
			next_btn.text = "Next Mission — %s  %s" % [GameState.stage_code(nxt), next_data.title]
		else:
			next_btn.text = "Next Mission — %s" % GameState.stage_code(nxt)
	else:
		next_btn.visible = false
		if GameState.last_won and GameState.is_sector_finale():
			again_btn.text = "Replay Finale"


func _focus_primary() -> void:
	if next_btn.visible:
		next_btn.grab_focus()
	else:
		again_btn.grab_focus()


func _on_next() -> void:
	if not GameState.has_next_mission():
		return
	AudioBus.play_ui()
	GameState.start_campaign_mission(GameState.next_mission_index())
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


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
