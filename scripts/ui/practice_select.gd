extends Control
## Practice mode: launch any stage from any wave at a chosen power tier.
## Wave options: Start (wave 0), each wave index (1-based), or BOSS.

@onready var list: VBoxContainer = $Center/VBox/Scroll/MissionList
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	AudioBus.play_menu_music()
	_build_list()


func _build_list() -> void:
	for child in list.get_children():
		child.queue_free()
	_add_header("SECTOR 1 — To the Flagship Core")
	for i in GameState.SECTOR_1_COUNT:
		_add_row(i)
	_add_header("SECTOR 2 — Beyond the Dawn Gate")
	for i in range(GameState.SECTOR_1_COUNT, GameState.MISSION_PATHS.size()):
		_add_row(i)
	back_btn.grab_focus()


func _add_header(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
	list.add_child(h)


func _add_row(index: int) -> void:
	var data: MissionData = GameState.get_mission_data(index)
	var wave_count := data.waves.size() if data else 6
	var wave := 0 ## 0-based; wave_count = boss
	var power := 2

	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.custom_minimum_size = Vector2(230, 0)
	name_lbl.text = "%d-%d  %s" % [data.sector, data.stage, data.title] if data else GameState.stage_code(index)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	hbox.add_child(_small_label("Wave"))
	var wave_minus := Button.new()
	wave_minus.text = "◀"
	wave_minus.custom_minimum_size = Vector2(34, 34)
	hbox.add_child(wave_minus)
	var wave_lbl := Label.new()
	wave_lbl.custom_minimum_size = Vector2(78, 0)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(wave_lbl)
	var wave_plus := Button.new()
	wave_plus.text = "▶"
	wave_plus.custom_minimum_size = Vector2(34, 34)
	hbox.add_child(wave_plus)

	hbox.add_child(_small_label("Power"))
	var power_minus := Button.new()
	power_minus.text = "◀"
	power_minus.custom_minimum_size = Vector2(34, 34)
	hbox.add_child(power_minus)
	var power_lbl := Label.new()
	power_lbl.custom_minimum_size = Vector2(44, 0)
	power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(power_lbl)
	var power_plus := Button.new()
	power_plus.text = "▶"
	power_plus.custom_minimum_size = Vector2(34, 34)
	hbox.add_child(power_plus)

	var start_btn := Button.new()
	start_btn.text = "START"
	start_btn.custom_minimum_size = Vector2(86, 34)
	hbox.add_child(start_btn)

	_update_labels(wave_lbl, power_lbl, wave, wave_count, power)

	wave_minus.pressed.connect(func() -> void:
		wave = maxi(0, wave - 1)
		_update_labels(wave_lbl, power_lbl, wave, wave_count, power)
	)
	wave_plus.pressed.connect(func() -> void:
		wave = mini(wave_count, wave + 1)
		_update_labels(wave_lbl, power_lbl, wave, wave_count, power)
	)
	power_minus.pressed.connect(func() -> void:
		power = maxi(1, power - 1)
		_update_labels(wave_lbl, power_lbl, wave, wave_count, power)
	)
	power_plus.pressed.connect(func() -> void:
		power = mini(3, power + 1)
		_update_labels(wave_lbl, power_lbl, wave, wave_count, power)
	)
	start_btn.pressed.connect(func() -> void: _start(index, wave, power))

	list.add_child(panel)


func _small_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _update_labels(wave_lbl: Label, power_lbl: Label, wave: int, wave_count: int, power: int) -> void:
	if wave >= wave_count:
		wave_lbl.text = "BOSS"
	else:
		wave_lbl.text = "%d/%d" % [wave + 1, wave_count]
	power_lbl.text = "Lv%d" % power


func _start(index: int, wave: int, power: int) -> void:
	AudioBus.play_ui()
	GameState.start_practice(index, wave, power)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
