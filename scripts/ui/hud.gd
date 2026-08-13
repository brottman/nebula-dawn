extends CanvasLayer
## Screen layout:
##   PLAYFIELD   — clear action zone
##   BOTTOM LEFT — Bomb button (tap)

@onready var wave_label: Label = $Root/WaveLabel
@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var combo_label: Label = $Root/ComboLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast
@onready var root: Control = $Root
@onready var bomb_btn: Button = $Root/BombButton

var _bombs: int = 0


func _ready() -> void:
	boss_bar.visible = false
	boss_label.visible = false
	pickup_toast.visible = false
	bomb_btn.focus_mode = Control.FOCUS_NONE
	bomb_btn.pressed.connect(_on_bomb_pressed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	EventBus.player_hp_changed.connect(_on_hp)
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
	# Initial sync in case the player's first emit beat us to the connect.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_on_hp(int(player.hp), int(player.max_hp))
	if has_node("Root/OverdriveBar"):
		$Root/OverdriveBar.visible = false
		$Root/OverdriveBar.max_value = 100.0
		$Root/OverdriveBar.value = 0.0


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


func _on_bombs(bombs: int) -> void:
	_bombs = bombs
	bomb_btn.text = "BOMB\nx%d" % bombs
	bomb_btn.modulate = Color(1, 1, 1, 1) if bombs > 0 else Color(1, 1, 1, 0.4)


func _on_hp(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


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


func _on_pickup(kind: String) -> void:
	pickup_toast.visible = true
	var names := {
		"spread": "SPREAD", "vulcan": "SPREAD", "red": "SPREAD",
		"laser": "LASER", "beam": "LASER", "blue": "LASER",
		"homing": "HOMING", "missiles": "HOMING", "green": "HOMING",
		"power": "P-CHIP", "pchip": "P-CHIP", "p-chip": "P-CHIP", "gold": "P-CHIP",
		"power_orb": "POWER ORB", "orb": "POWER ORB",
		"option": "DRONE", "bit": "DRONE", "drone": "DRONE",
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
