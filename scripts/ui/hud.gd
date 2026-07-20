extends CanvasLayer
## In-run HUD: HP, score, wave, boss bar.

@onready var hp_label: Label = $Root/HPLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var boss_bar: ProgressBar = $Root/BossBar
@onready var boss_label: Label = $Root/BossLabel
@onready var pickup_toast: Label = $Root/PickupToast


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
	_on_score(GameState.session_score)
	_on_hp(5, 5)
	if GameState.mode == GameState.Mode.ENDLESS:
		wave_label.text = "ENDLESS"


func _on_hp(current: int, maximum: int) -> void:
	hp_label.text = "HP  " + "◆".repeat(current) + "◇".repeat(maxi(0, maximum - current))


func _on_score(value: int) -> void:
	score_label.text = "SCORE  %06d" % value


func _on_wave(index: int, total: int) -> void:
	wave_label.text = "WAVE  %d / %d" % [index + 1, total]


func _on_boss_spawned(_boss: Node) -> void:
	boss_bar.visible = true
	boss_label.visible = true
	boss_label.text = "NEBULA CORE"
	wave_label.text = "BOSS"


func _on_boss_hp(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_defeated() -> void:
	boss_bar.visible = false
	boss_label.visible = false


func _on_pickup(kind: String) -> void:
	pickup_toast.visible = true
	pickup_toast.text = kind.to_upper() + "!"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(pickup_toast):
		pickup_toast.visible = false
