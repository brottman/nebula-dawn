extends "res://scripts/stage/gimmicks/stage_gimmick.gd"
## Stage 2-3: fog + delayed echo volleys at the player's last lane.

var _fog: ColorRect


func begin() -> void:
	super.begin()
	EventBus.gimmick_toast.emit("PHANTOM WAKE")
	_ensure_fog()


func tick(delta: float) -> void:
	super.tick(delta)
	if _fog:
		var wave := 0.5 + 0.5 * sin(timer * 1.1)
		var amp := 0.07 if GameState.reduce_flashes else 0.16
		_fog.color.a = 0.06 + amp * wave
		var vp := vp_size()
		_fog.offset_top = vp.y * (0.35 + 0.1 * sin(timer * 0.7))
	if pulse <= 0.0:
		pulse = rng.randf_range(2.4, 3.8)
		_spawn_phantom_echo()


func cleanup() -> void:
	if _fog and is_instance_valid(_fog):
		var layer := _fog.get_parent()
		_fog.queue_free()
		_fog = null
		if layer and is_instance_valid(layer):
			layer.queue_free()
	super.cleanup()


func _ensure_fog() -> void:
	if _fog:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_fog = ColorRect.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.color = Color(0.2, 0.35, 0.55, 0.0)
	layer.add_child(_fog)


func _spawn_phantom_echo() -> void:
	if pool == null or player == null or not is_instance_valid(player) or player.get("dead") == true:
		return
	var target: Vector2 = player.global_position
	get_tree().create_timer(0.45).timeout.connect(_fire_phantom_echo.bind(target))


func _fire_phantom_echo(target: Vector2) -> void:
	if pool == null:
		return
	var muzzle := Vector2(target.x, 40.0)
	for i in 3:
		var a := -0.22 + 0.22 * float(i)
		pool.spawn_enemy(muzzle, Vector2(a, 1).normalized() * 210.0, 1.0, {
			"color": Color(0.45, 0.7, 1.0, 0.55),
			"scale": 0.85,
		})
	AudioBus.play_enemy_shoot()
	EventBus.gimmick_toast.emit("ECHO")
