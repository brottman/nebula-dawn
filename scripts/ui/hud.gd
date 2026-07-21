extends CanvasLayer
## In-run HUD: HP, lives, bombs, score, wave, boss bar.

@onready var hp_label: Label = $Root/HPLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast
@onready var weapon_label: Label = $Root/WeaponLabel

var _lives_label: Label
var _bomb_label: Label
var _bomb_btn: Button


func _ready() -> void:
	boss_bar.visible = false
	boss_label.visible = false
	pickup_toast.visible = false
	_ensure_status_labels()
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.score_changed.connect(_on_score)
	EventBus.wave_started.connect(_on_wave)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.gimmick_toast.connect(_on_gimmick_toast)
	EventBus.overdrive_changed.connect(_on_overdrive)
	EventBus.player_lives_changed.connect(_on_lives)
	EventBus.bomb_stock_changed.connect(_on_bombs)
	_on_score(GameState.session_score)
	_on_hp(5, 5)
	_on_lives(3)
	_on_bombs(0)
	if GameState.mode == GameState.Mode.ENDLESS:
		wave_label.text = "ENDLESS"
	if has_node("Root/OverdriveBar"):
		$Root/OverdriveBar.visible = false
		$Root/OverdriveBar.max_value = 100.0
		$Root/OverdriveBar.value = 0.0


func _ensure_status_labels() -> void:
	var root: Control = $Root
	_lives_label = root.get_node_or_null("LivesLabel")
	if _lives_label == null:
		_lives_label = Label.new()
		_lives_label.name = "LivesLabel"
		_lives_label.position = Vector2(16, 56)
		_lives_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_lives_label.add_theme_font_size_override("font_size", 14)
		root.add_child(_lives_label)
	_bomb_label = root.get_node_or_null("BombLabel")
	if _bomb_label == null:
		_bomb_label = Label.new()
		_bomb_label.name = "BombLabel"
		_bomb_label.position = Vector2(16, 76)
		_bomb_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_bomb_label.add_theme_font_size_override("font_size", 14)
		root.add_child(_bomb_label)
	_bomb_btn = root.get_node_or_null("BombButton")
	if _bomb_btn == null:
		_bomb_btn = Button.new()
		_bomb_btn.name = "BombButton"
		_bomb_btn.text = "BOMB"
		_bomb_btn.focus_mode = Control.FOCUS_NONE
		_bomb_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_bomb_btn.offset_left = -100.0
		_bomb_btn.offset_top = -100.0
		_bomb_btn.offset_right = -16.0
		_bomb_btn.offset_bottom = -36.0
		_bomb_btn.pressed.connect(_on_bomb_pressed)
		root.add_child(_bomb_btn)


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


func _on_lives(lives: int) -> void:
	if _lives_label:
		_lives_label.text = "SHIPS  " + "▲".repeat(maxi(0, lives))


func _on_bombs(bombs: int) -> void:
	if _bomb_label:
		_bomb_label.text = "BOMB  ×%d" % bombs
	if _bomb_btn:
		_bomb_btn.disabled = false ## keep pressable during death-bomb even at 0 briefly
		_bomb_btn.modulate = Color(1, 1, 1, 1) if bombs > 0 else Color(1, 1, 1, 0.35)


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
	hp_label.text = "HP  " + "◆".repeat(current) + "◇".repeat(maxi(0, maximum - current))


func _on_score(value: int) -> void:
	score_label.text = "SCORE  %06d" % value


func _on_wave(_index: int, _total: int, label: String = "") -> void:
	if label != "":
		wave_label.text = label.to_upper()
	else:
		wave_label.text = "WAVE"


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


func _on_weapon_changed(weapon_name: String) -> void:
	weapon_label.visible = weapon_name != ""
	weapon_label.text = weapon_name


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
