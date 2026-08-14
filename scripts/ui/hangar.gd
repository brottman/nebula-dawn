extends Control
## Buy hulls, rank their systems, and equip a strike craft for the next sortie.

const Ships := preload("res://scripts/hangar/ship_catalog.gd")

@onready var credits_label: Label = $VBox/Credits
@onready var ship_list: VBoxContainer = $VBox/Scroll/Content/ShipList
@onready var portrait: TextureRect = $VBox/Scroll/Content/Portrait
@onready var name_label: Label = $VBox/Scroll/Content/ShipName
@onready var role_label: Label = $VBox/Scroll/Content/Role
@onready var blurb_label: Label = $VBox/Scroll/Content/Blurb
@onready var stats_label: Label = $VBox/Scroll/Content/Stats
@onready var action_btn: Button = $VBox/Scroll/Content/ActionButton
@onready var upgrade_list: VBoxContainer = $VBox/Scroll/Content/UpgradeList
@onready var back_btn: Button = $VBox/BackButton

var _preview_id: String = Ships.STARTER_ID
var _return_scene: String = "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	_return_scene = GameState.hangar_return_scene if GameState.hangar_return_scene != "" else "res://scenes/ui/main_menu.tscn"
	_preview_id = GameState.selected_ship_id
	if Ships.get_def(_preview_id).is_empty():
		_preview_id = Ships.STARTER_ID
	back_btn.pressed.connect(_on_back)
	action_btn.pressed.connect(_on_action)
	_rebuild()
	AudioBus.play_menu_music()


func _rebuild() -> void:
	_refresh_credits()
	_rebuild_ships()
	_refresh_detail()
	_rebuild_upgrades()


func _refresh_credits() -> void:
	credits_label.text = "CREDITS  %s" % Ships.format_credits(GameState.credits)


func _clear_children(host: Node) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.free()


func _rebuild_ships() -> void:
	_clear_children(ship_list)
	var focus_btn: Button = null
	for def in Ships.all_defs():
		var id := String(def["id"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.text = _ship_button_text(def)
		if id == _preview_id:
			btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
			focus_btn = btn
		btn.pressed.connect(_on_pick_ship.bind(id))
		ship_list.add_child(btn)
	if focus_btn:
		focus_btn.grab_focus()


func _ship_button_text(def: Dictionary) -> String:
	var id := String(def["id"])
	var name := String(def["name"])
	var mark := "▸ " if id == _preview_id else "   "
	if id == GameState.selected_ship_id:
		return "%s%s  —  EQUIPPED" % [mark, name]
	if GameState.is_ship_owned(id):
		return "%s%s  —  OWNED" % [mark, name]
	return "%s%s  —  %s cr" % [mark, name, Ships.format_credits(int(def.get("cost", 0)))]


func _on_pick_ship(ship_id: String) -> void:
	AudioBus.play_ui()
	_preview_id = ship_id
	_rebuild()


func _refresh_detail() -> void:
	var spec: Dictionary = GameState.get_loadout_for(_preview_id)
	name_label.text = String(spec.get("name", "Unknown"))
	role_label.text = String(spec.get("role", ""))
	blurb_label.text = String(spec.get("blurb", ""))
	stats_label.text = Ships.stats_text(spec)
	var tint_val: Variant = spec.get("tint", Color(1.0, 1.0, 1.0, 1.0))
	if tint_val is Color:
		portrait.modulate = tint_val
	else:
		portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var path := String(spec.get("sprite", "res://assets/sprites/player_ship.svg"))
	if FileAccess.file_exists(path):
		portrait.texture = load(path) as Texture2D
	if GameState.is_ship_owned(_preview_id):
		if _preview_id == GameState.selected_ship_id:
			action_btn.text = "Equipped"
			action_btn.disabled = true
		else:
			action_btn.text = "Equip"
			action_btn.disabled = false
	else:
		var cost := int(spec.get("cost", 0))
		action_btn.text = "Buy  %s cr" % Ships.format_credits(cost)
		action_btn.disabled = GameState.credits < cost


func _rebuild_upgrades() -> void:
	_clear_children(upgrade_list)
	var owned := GameState.is_ship_owned(_preview_id)
	var ranks: Dictionary = GameState.get_ship_ranks(_preview_id)
	for key in Ships.UPGRADE_KEYS:
		var rank := int(ranks.get(key, 0))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		var label := String(Ships.UPGRADE_LABELS.get(key, key))
		var hint := String(Ships.UPGRADE_HINTS.get(key, ""))
		if not owned:
			btn.text = "%s  —  own this hull" % label
			btn.disabled = true
		elif rank >= Ships.MAX_UPGRADE:
			btn.text = "%s  %d/%d  MAX" % [label, rank, Ships.MAX_UPGRADE]
			btn.disabled = true
		else:
			var cost := Ships.upgrade_cost(rank)
			btn.text = "%s  %d/%d   %s cr" % [label, rank, Ships.MAX_UPGRADE, Ships.format_credits(cost)]
			btn.disabled = GameState.credits < cost
			btn.pressed.connect(_on_upgrade.bind(String(key)))
		upgrade_list.add_child(btn)
		var hint_lbl := Label.new()
		hint_lbl.text = hint
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
		upgrade_list.add_child(hint_lbl)


func _on_action() -> void:
	if GameState.is_ship_owned(_preview_id):
		if GameState.select_ship(_preview_id):
			AudioBus.play_ui()
			_rebuild()
		return
	if GameState.buy_ship(_preview_id) and GameState.select_ship(_preview_id):
		AudioBus.play_ui()
		_rebuild()


func _on_upgrade(key: String) -> void:
	if GameState.buy_upgrade(_preview_id, key):
		AudioBus.play_ui()
		_rebuild()


func _on_back() -> void:
	AudioBus.play_ui()
	get_tree().change_scene_to_file(_return_scene)