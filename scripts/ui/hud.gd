extends CanvasLayer
## In-run HUD: HP, score, wave, boss bar.

@onready var hp_label: Label = $Root/HPLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast
@onready var weapon_label: Label = $Root/WeaponLabel


func _ready() -> void:
	boss_bar.visible = false
	boss_label.visible = false
	pickup_toast.visible = false
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
	_on_score(GameState.session_score)
	_on_hp(5, 5)
	if GameState.mode == GameState.Mode.ENDLESS:
		wave_label.text = "ENDLESS"
	if has_node("Root/OverdriveBar"):
		$Root/OverdriveBar.visible = false
		$Root/OverdriveBar.max_value = 100.0
		$Root/OverdriveBar.value = 0.0


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
