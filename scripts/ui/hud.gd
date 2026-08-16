extends CanvasLayer
## Screen layout:
##   TOP BAR     — lives + HP | weapon badge + Power | score
##   PLAYFIELD   — clear action zone
##   BOTTOM      — Bomb (left) / Pause (right)

const CHIP_EMPTY := Color(0.18, 0.22, 0.32, 1.0)
const CHIP_MAX := Color(1.0, 0.82, 0.35, 1.0)
const SLOT_COLOR := {
	"BLASTER": Color(0.78, 0.84, 0.95, 1.0),
	"SPREAD": Color(1.0, 0.4, 0.34, 1.0),
	"LASER": Color(0.4, 0.72, 1.0, 1.0),
	"HOMING": Color(0.42, 0.95, 0.55, 1.0),
}
const SLOT_TAG := {
	"BLASTER": "---",
	"SPREAD": "RED",
	"LASER": "BLUE",
	"HOMING": "GREEN",
}
const SLOT_TITLE := {
	"BLASTER": "BLASTER",
	"SPREAD": "SPREAD",
	"LASER": "LASER",
	"HOMING": "HOMING",
}

@onready var wave_label: Label = $Root/WaveLabel
@onready var health_bar: ProgressBar = $Root/TopBar/Margin/Row/Left/HealthBar
@onready var lives_label: Label = $Root/TopBar/Margin/Row/Left/LivesLabel
@onready var weapon_badge: Label = $Root/TopBar/Margin/Row/Center/WeaponRow/WeaponBadge
@onready var weapon_level: Label = $Root/TopBar/Margin/Row/Center/WeaponRow/WeaponLevel
@onready var chip_row: HBoxContainer = $Root/TopBar/Margin/Row/Center/ChipRow
@onready var chip_count: Label = $Root/TopBar/Margin/Row/Center/ChipRow/ChipCount
@onready var extras_label: Label = $Root/TopBar/Margin/Row/Center/ExtrasLabel
@onready var score_label: Label = $Root/TopBar/Margin/Row/Right/ScoreLabel
@onready var combo_label: Label = $Root/ComboLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast
@onready var overdrive_bar: ProgressBar = $Root/OverdriveBar
@onready var root: Control = $Root
@onready var bomb_btn: Button = $Root/BombButton
@onready var weapon_btn: Button = $Root/WeaponButton
@onready var pause_btn: Button = $Root/PauseButton

var _bombs: int = 0
var _chips: Array[ColorRect] = []


func _ready() -> void:
	for child in chip_row.get_children():
		if child is ColorRect:
			_chips.append(child)
	boss_bar.visible = false
	boss_label.visible = false
	pickup_toast.visible = false
	bomb_btn.focus_mode = Control.FOCUS_NONE
	weapon_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.focus_mode = Control.FOCUS_NONE
	bomb_btn.pressed.connect(_on_bomb_pressed)
	weapon_btn.pressed.connect(_on_weapon_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	weapon_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	weapon_badge.gui_input.connect(_on_weapon_badge_input)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_lives_changed.connect(_on_lives)
	EventBus.score_changed.connect(_on_score)
	EventBus.weapon_tier_changed.connect(_on_weapon_tier)
	EventBus.wave_started.connect(_on_wave)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.gimmick_toast.connect(_on_gimmick_toast)
	EventBus.overdrive_changed.connect(_on_overdrive)
	EventBus.bomb_stock_changed.connect(_on_bombs)
	EventBus.combo_changed.connect(_on_combo)
	_on_bombs(0)
	_on_score(GameState.session_score)
	_refresh_overdrive(0.0, 100.0)
	# Player _ready runs before HUD (deeper in the tree); re-sync + re-emit.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_on_hp(int(player.hp), int(player.max_hp))
		_on_lives(int(player.lives))
		if player.has_method("_emit_weapon_changed"):
			player._emit_weapon_changed()
		else:
			_on_weapon_tier("BLASTER", 1, 0, 5, "")
	else:
		_on_weapon_tier("BLASTER", 1, 0, 5, "")


## Keep chrome clear of notches / punch-hole cameras (immersive Android).
func _apply_safe_area() -> void:
	var insets := _safe_area_insets()
	root.offset_left = insets.x
	root.offset_top = insets.y
	root.offset_right = -insets.z
	root.offset_bottom = -insets.w


func _safe_area_insets() -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return Vector4.ZERO
	var vp := get_viewport().get_visible_rect().size
	var left := float(safe.position.x) / float(screen.x) * vp.x
	var top := float(safe.position.y) / float(screen.y) * vp.y
	var right := float(screen.x - safe.end.x) / float(screen.x) * vp.x
	var bottom := float(screen.y - safe.end.y) / float(screen.y) * vp.y
	return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))


func _on_pause_pressed() -> void:
	EventBus.pause_requested.emit()


func _on_weapon_pressed() -> void:
	_cycle_player_weapon()


func _on_weapon_badge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cycle_player_weapon()
	elif event is InputEventScreenTouch and event.pressed:
		_cycle_player_weapon()


func _cycle_player_weapon() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("player"):
		if n.has_method("cycle_weapon"):
			n.cycle_weapon()
			return


func _on_bomb_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("player"):
		if n.get("_death_bomb_time") != null and float(n._death_bomb_time) > 0.0:
			if n.has_method("_try_death_bomb"):
				n._try_death_bomb()
			return
		if n.has_method("try_use_bomb"):
			n.try_use_bomb()
			return


func _on_bombs(bombs: int) -> void:
	_bombs = bombs
	bomb_btn.text = "BOMB\nx%d" % bombs
	bomb_btn.modulate = Color(1, 1, 1, 1) if bombs > 0 else Color(1, 1, 1, 0.4)


func _on_hp(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_lives(lives: int) -> void:
	lives_label.text = "×%d" % lives


func _on_score(new_score: int) -> void:
	score_label.text = "%06d" % new_score


func _on_weapon_tier(slot: String, level: int, chips: int, chips_needed: int, extras: String) -> void:
	var key := slot.to_upper()
	var color: Color = SLOT_COLOR.get(key, SLOT_COLOR["BLASTER"])
	var tag: String = SLOT_TAG.get(key, "---")
	var title: String = SLOT_TITLE.get(key, key)
	weapon_badge.text = "[%s] %s" % [tag, title]
	weapon_badge.add_theme_color_override("font_color", color)
	var at_max := level >= 3 and chips >= chips_needed
	weapon_level.text = "MAX" if at_max else "LV %d" % level
	weapon_level.add_theme_color_override("font_color", CHIP_MAX if at_max else color)
	var fill_color: Color = CHIP_MAX if key == "BLASTER" else color
	var needed := maxi(chips_needed, 1)
	var filled := needed if at_max else clampi(chips, 0, needed)
	for i in _chips.size():
		_chips[i].color = CHIP_MAX if at_max else (fill_color if i < filled else CHIP_EMPTY)
	chip_count.text = "MAX" if at_max else "%d/%d" % [filled, needed]
	if extras.strip_edges() == "":
		extras_label.visible = false
		extras_label.text = ""
	else:
		extras_label.visible = true
		extras_label.text = extras
	var can_switch := extras.contains("WEP")
	weapon_btn.modulate = Color(1, 1, 1, 1) if can_switch else Color(1, 1, 1, 0.4)


func _on_gimmick_toast(text: String) -> void:
	pickup_toast.visible = true
	pickup_toast.text = text
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(pickup_toast):
		pickup_toast.visible = false


func _stage_uses_overdrive() -> bool:
	var data := GameState.get_mission_data()
	if data == null:
		return false
	return data.gimmick_id == &"gravity" or data.gimmick_id == &"flare"


func _refresh_overdrive(current: float, maximum: float) -> void:
	overdrive_bar.max_value = maximum
	overdrive_bar.value = current
	overdrive_bar.visible = current > 0.0 or _stage_uses_overdrive()


func _on_overdrive(current: float, maximum: float) -> void:
	_refresh_overdrive(current, maximum)


func _on_wave(_index: int, _total: int, label: String = "") -> void:
	if label != "":
		wave_label.text = label.to_upper()
	else:
		wave_label.text = "WAVE"
	_refresh_overdrive(overdrive_bar.value, overdrive_bar.max_value)


func _on_combo(combo: int) -> void:
	if combo >= 2:
		combo_label.visible = true
		combo_label.text = "CHAIN ×%d" % combo
		var heat := clampf(0.4 + float(combo) * 0.02, 0.4, 1.0)
		combo_label.modulate = Color(1.0, heat, heat * 0.4, 1.0)
	else:
		combo_label.visible = false


func _on_boss_spawned(boss: Node) -> void:
	boss_bar.visible = true
	boss_label.visible = true
	var stats: EnemyStats = boss.get("stats")
	var is_mid := false
	if stats:
		boss_label.text = stats.display_name.to_upper()
		is_mid = stats.is_mid_boss
	else:
		boss_label.text = "WARNING"
	wave_label.text = "ACT 3 — MID-BOSS" if is_mid else "ACT 5 — STAGE BOSS"
	_refresh_overdrive(overdrive_bar.value, overdrive_bar.max_value)


func _on_boss_hp(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_defeated() -> void:
	boss_bar.visible = false
	boss_label.visible = false


func _on_pickup(kind: String) -> void:
	# Weapon / Power already toast exact progress via EventBus.gimmick_toast.
	# Don't overwrite "POWER  2/5" with a generic "POWER!".
	if kind in [
		"spread", "vulcan", "red", "laser", "beam", "blue", "homing", "missiles", "green",
		"power", "pchip", "p-chip", "gold", "power_orb", "orb",
		"option", "bit", "drone", "speed",
	]:
		return
	pickup_toast.visible = true
	var names := {
		"spread": "SPREAD", "vulcan": "SPREAD", "red": "SPREAD",
		"laser": "LASER", "beam": "LASER", "blue": "LASER",
		"homing": "HOMING", "missiles": "HOMING", "green": "HOMING",
		"power": "POWER", "pchip": "POWER", "p-chip": "POWER", "gold": "POWER",
		"power_orb": "POWER ORB", "orb": "POWER ORB",
		"option": "DRONE", "bit": "DRONE", "drone": "DRONE",
		"speed": "SPEED",
		"shield": "SHIELD", "barrier": "SHIELD",
		"bomb": "BOMB", "cleaver": "BOMB",
		"energy": "HEAL", "overdrive_pickup": "HEAL", "rapid": "HEAL",
		"heal": "HEAL",
	}
	var toast: String = str(names.get(kind, kind.to_upper()))
	pickup_toast.text = toast + "!"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(pickup_toast):
		pickup_toast.visible = false