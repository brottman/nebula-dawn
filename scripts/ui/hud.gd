extends CanvasLayer
## Screen layout:
##   TOP HUD BAR — HP/Lives | Weapon badge + tier + chip segments | Score
##   PLAYFIELD   — clear action zone
##   BOTTOM LEFT — Bomb button (tap)

const CHIP_SEGMENTS := 5

@onready var hp_lives_label: Label = $Root/TopBar/HPLivesLabel
@onready var weapon_module: PanelContainer = $Root/TopBar/WeaponModule
@onready var weapon_badge: PanelContainer = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/TopRow/WeaponBadge
@onready var badge_label: Label = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/TopRow/WeaponBadge/BadgeLabel
@onready var weapon_title: Label = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/TopRow/WeaponTitle
@onready var weapon_level_label: Label = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/TopRow/WeaponLevelLabel
@onready var chip_segments: HBoxContainer = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/ChipRow/ChipSegments
@onready var chip_count_label: Label = $Root/TopBar/WeaponModule/ModuleMargin/ModuleVBox/ChipRow/ChipCountLabel
@onready var score_label: Label = $Root/TopBar/ScoreLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var combo_label: Label = $Root/ComboLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast
@onready var root: Control = $Root
@onready var bomb_btn: Button = $Root/BombButton

var _hp: int = 5
var _max_hp: int = 5
var _lives: int = 3
var _bombs: int = 0
var _segment_panels: Array[ColorRect] = []
var _module_style: StyleBoxFlat
var _badge_style: StyleBoxFlat


func _ready() -> void:
	boss_bar.visible = false
	boss_label.visible = false
	pickup_toast.visible = false
	bomb_btn.focus_mode = Control.FOCUS_NONE
	bomb_btn.pressed.connect(_on_bomb_pressed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_build_weapon_module_styles()
	_build_chip_segments()
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.score_changed.connect(_on_score)
	EventBus.wave_started.connect(_on_wave)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.weapon_tier_changed.connect(_on_weapon_tier)
	EventBus.gimmick_toast.connect(_on_gimmick_toast)
	EventBus.overdrive_changed.connect(_on_overdrive)
	EventBus.player_lives_changed.connect(_on_lives)
	EventBus.bomb_stock_changed.connect(_on_bombs)
	EventBus.combo_changed.connect(_on_combo)
	_on_score(GameState.session_score)
	_on_hp(5, 5)
	_on_lives(3)
	_on_bombs(0)
	_on_weapon_tier("BLASTER", 1, 0, CHIP_SEGMENTS, "")
	if GameState.mode == GameState.Mode.ENDLESS:
		wave_label.text = "ENDLESS"
	if has_node("Root/OverdriveBar"):
		$Root/OverdriveBar.visible = false
		$Root/OverdriveBar.max_value = 100.0
		$Root/OverdriveBar.value = 0.0


func _build_weapon_module_styles() -> void:
	_module_style = StyleBoxFlat.new()
	_module_style.bg_color = Color(0.05, 0.08, 0.12, 0.82)
	_module_style.set_border_width_all(1)
	_module_style.border_color = Color(1, 1, 1, 0.18)
	_module_style.set_corner_radius_all(6)
	_module_style.content_margin_left = 0
	weapon_module.add_theme_stylebox_override("panel", _module_style)

	_badge_style = StyleBoxFlat.new()
	_badge_style.bg_color = Color(0.45, 0.5, 0.58, 0.95)
	_badge_style.set_corner_radius_all(4)
	_badge_style.content_margin_left = 4
	_badge_style.content_margin_right = 4
	_badge_style.content_margin_top = 2
	_badge_style.content_margin_bottom = 2
	weapon_badge.add_theme_stylebox_override("panel", _badge_style)


func _build_chip_segments() -> void:
	for child in chip_segments.get_children():
		child.queue_free()
	_segment_panels.clear()
	for i in CHIP_SEGMENTS:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 12)
		seg.color = Color(0.18, 0.22, 0.28, 0.95)
		chip_segments.add_child(seg)
		_segment_panels.append(seg)


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


func _refresh_hp_lives() -> void:
	var hearts := "❤".repeat(maxi(0, _hp))
	if _hp < _max_hp:
		hearts += "♡".repeat(_max_hp - _hp)
	var ships := "▲".repeat(maxi(0, _lives))
	hp_lives_label.text = hearts + "\n" + ships


func _on_lives(lives: int) -> void:
	_lives = lives
	_refresh_hp_lives()


func _on_bombs(bombs: int) -> void:
	_bombs = bombs
	bomb_btn.text = "BOMB\nx%d" % bombs
	bomb_btn.modulate = Color(1, 1, 1, 1) if bombs > 0 else Color(1, 1, 1, 0.4)


func _on_gimmick_toast(text: String) -> void:
	pickup_toast.visible = true
	pickup_toast.text = text
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(pickup_toast):
		pickup_toast.visible = false


func _on_overdrive(current: float, maximum: float) -> void:
	if not has_node("Root/OverdriveBar"):
		return
	var bar: ProgressBar = $Root/OverdriveBar
	bar.visible = current > 0.0 or GameState.current_mission_index == 4
	bar.max_value = maximum
	bar.value = current


func _on_hp(current: int, maximum: int) -> void:
	_hp = current
	_max_hp = maximum
	_refresh_hp_lives()


func _on_score(value: int) -> void:
	score_label.text = "%s" % _format_score(value)


func _format_score(value: int) -> String:
	var s := "%d" % value
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = "," + out
		out = s[c_i] + out
		i += 1
	return out


func _on_wave(_index: int, _total: int, label: String = "") -> void:
	if label != "":
		wave_label.text = label.to_upper()
	else:
		wave_label.text = "WAVE"


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


func _on_boss_hp(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_defeated() -> void:
	boss_bar.visible = false
	boss_label.visible = false


func _on_weapon_changed(_weapon_name: String) -> void:
	pass


func _weapon_palette(slot: String) -> Dictionary:
	match slot:
		"SPREAD":
			return {
				"badge": Color(0.92, 0.22, 0.22, 0.98),
				"border": Color(1.0, 0.45, 0.4, 0.85),
				"fill": Color(1.0, 0.38, 0.32, 1.0),
				"empty": Color(0.28, 0.12, 0.12, 0.95),
				"tag": "RED",
				"title": "SPREAD BEAM",
			}
		"LASER":
			return {
				"badge": Color(0.18, 0.48, 0.95, 0.98),
				"border": Color(0.5, 0.78, 1.0, 0.85),
				"fill": Color(0.4, 0.78, 1.0, 1.0),
				"empty": Color(0.1, 0.16, 0.28, 0.95),
				"tag": "BLUE",
				"title": "FOCUSED LASER",
			}
		"HOMING":
			return {
				"badge": Color(0.16, 0.72, 0.28, 0.98),
				"border": Color(0.45, 1.0, 0.55, 0.85),
				"fill": Color(0.35, 0.95, 0.45, 1.0),
				"empty": Color(0.1, 0.22, 0.12, 0.95),
				"tag": "GREEN",
				"title": "HOMING MISS",
			}
		_:
			return {
				"badge": Color(0.42, 0.48, 0.56, 0.95),
				"border": Color(0.75, 0.8, 0.88, 0.55),
				"fill": Color(0.7, 0.76, 0.85, 0.95),
				"empty": Color(0.16, 0.2, 0.26, 0.95),
				"tag": "—",
				"title": "BLASTER",
			}


func _on_weapon_tier(slot: String, level: int, chips: int, chips_needed: int, extras: String) -> void:
	var pal: Dictionary = _weapon_palette(slot)
	badge_label.text = str(pal["tag"])
	_badge_style.bg_color = pal["badge"]
	_module_style.border_color = pal["border"]
	weapon_title.text = str(pal["title"])
	if extras != "":
		weapon_title.text += "  " + extras

	var at_max := level >= 3 and chips >= chips_needed
	if at_max:
		weapon_level_label.text = "MAX"
	else:
		weapon_level_label.text = "LV %d" % level

	var filled := chips_needed if at_max else clampi(chips, 0, chips_needed)
	for i in _segment_panels.size():
		_segment_panels[i].color = pal["fill"] if i < filled else pal["empty"]

	if at_max:
		chip_count_label.text = "MAXED"
	else:
		chip_count_label.text = "%d/%d P-CHIPS" % [filled, chips_needed]


func _on_pickup(kind: String) -> void:
	pickup_toast.visible = true
	var names := {
		"spread": "SPREAD", "vulcan": "SPREAD", "red": "SPREAD",
		"laser": "LASER", "beam": "LASER", "blue": "LASER",
		"homing": "HOMING", "missiles": "HOMING", "green": "HOMING",
		"power": "P-CHIP", "pchip": "P-CHIP", "p-chip": "P-CHIP", "gold": "P-CHIP",
		"power_orb": "POWER ORB", "orb": "POWER ORB",
		"option": "BIT", "bit": "BIT", "drone": "BIT",
		"speed": "SPEED",
		"shield": "SHIELD", "barrier": "SHIELD",
		"bomb": "BOMB", "cleaver": "BOMB",
		"energy": "ENERGY", "overdrive_pickup": "ENERGY", "rapid": "ENERGY",
		"heal": "HEAL",
	}
	var toast: String = str(names.get(kind, kind.to_upper()))
	pickup_toast.text = toast + "!"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(pickup_toast):
		pickup_toast.visible = false
