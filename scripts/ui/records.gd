extends Control
## Local records: per-mission best score + rank, endless top 5, boss rush best.

@onready var list: VBoxContainer = $Center/VBox/Scroll/RecordList
@onready var back_btn: Button = $Center/VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	AudioBus.play_menu_music()
	_build()


func _build() -> void:
	for child in list.get_children():
		child.queue_free()
	_add_header("CAMPAIGN")
	for i in GameState.MISSION_PATHS.size():
		_add_mission_row(i)
	_add_header("ENDLESS")
	var top := GameState.endless_top
	if top.is_empty():
		_add_row_text("No runs yet — dive in")
	else:
		for i in mini(top.size(), 5):
			var place := "%d." % (i + 1)
			_add_row_parts([place, "—", _fmt(top[i])], Color(0.55, 0.95, 0.75))
		var best_time := GameState.endless_best_time
		if best_time > 0.0:
			_add_row_parts(["", "Longest run", GameState.format_seconds(best_time)], Color(0.6, 0.7, 0.85))
	_add_header("BOSS RUSH")
	if GameState.boss_rush_high_score > 0:
		_add_row_parts(["", "Best raid", _fmt(GameState.boss_rush_high_score)], Color(0.55, 0.95, 0.75))
	else:
		_add_row_text("Clear Sector 2 to unlock the raid")
	back_btn.grab_focus()


func _add_header(text: String) -> void:
	var h := Label.new()
	h.text = "— %s —" % text
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
	h.add_theme_constant_override("outline_size", 0)
	list.add_child(h)


func _add_mission_row(index: int) -> void:
	var data: MissionData = GameState.get_mission_data(index)
	var title := "%d-%d  %s" % [data.sector, data.stage, data.title] if data else GameState.stage_code(index)
	var rank := GameState.get_best_rank(index)
	var score := GameState.get_best_score(index)
	var parts: Array[String] = [title]
	if rank != "":
		parts.append("[%s]" % rank)
	if score > 0:
		parts.append(_fmt(score))
	_add_row_parts(parts, Color(0.9, 0.95, 1) if score > 0 else Color(0.45, 0.5, 0.62))


func _add_row_parts(parts: Array[String], color: Color) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.text = "   ".join(parts)
	lbl.clip_text = true
	list.add_child(lbl)


func _add_row_text(text: String) -> void:
	_add_row_parts([text], Color(0.45, 0.5, 0.62))


func _fmt(v: int) -> String:
	var s := "%d" % v
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = "," + out
		out = s[c_i] + out
		i += 1
	return out


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
