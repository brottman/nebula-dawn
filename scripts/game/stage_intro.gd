extends CanvasLayer
## Full-screen stage title card: dim + letterbox bars retract to reveal the
## stage code / title / subtitle, hold, then slide away. Runs while the scene
## tree is paused (PROCESS_MODE_ALWAYS) so combat does not start mid-wipe.
## Any input skips straight to the fade-out.

signal finished

const CODE_COLOR := Color(1.0, 0.8, 0.38, 1.0)
const TITLE_COLOR := Color(0.88, 0.93, 1.0, 1.0)
const SUB_COLOR := Color(0.62, 0.7, 0.9, 1.0)
## Letterbox bar height as a fraction of the screen.
const BAR_THICKNESS := 0.13
const HOLD_TIME := 1.05

var _dim: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _code_label: Label
var _title_label: Label
var _sub_label: Label
var _tween: Tween
var _playing := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var vp := _viewport_size()

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_dim)

	_top_bar = ColorRect.new()
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.color = Color(0.0, 0.008, 0.025, 1.0)
	add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.color = Color(0.0, 0.008, 0.025, 1.0)
	add_child(_bottom_bar)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_code_label = _make_label(CODE_COLOR, 22)
	vbox.add_child(_code_label)

	_title_label = _make_label(TITLE_COLOR, 42)
	vbox.add_child(_title_label)

	_sub_label = _make_label(SUB_COLOR, 14)
	vbox.add_child(_sub_label)

	_reset_bars(vp)


func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = 0.0
	return label


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _reset_bars(vp: Vector2) -> void:
	## Bars start covering the whole screen; the wipe retracts them outward.
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(vp.x, vp.y * 0.5)
	_bottom_bar.position = Vector2(0.0, vp.y * 0.5)
	_bottom_bar.size = Vector2(vp.x, vp.y * 0.5)
	_dim.color.a = 0.0


func play(code_text: String, title_text: String, sub_text: String) -> void:
	if _playing:
		return
	_playing = true
	_code_label.text = code_text
	_title_label.text = title_text
	_sub_label.text = sub_text
	AudioBus.play_ui()
	var vp := _viewport_size()
	_reset_bars(vp)
	var thin := vp.y * BAR_THICKNESS

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "color:a", 0.6, 0.22)
	_tween.tween_property(_top_bar, "size:y", thin, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bottom_bar, "size:y", thin, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bottom_bar, "position:y", vp.y - thin, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_code_label, "modulate:a", 1.0, 0.3).set_delay(0.18)
	_tween.tween_property(_title_label, "modulate:a", 1.0, 0.35).set_delay(0.22)
	_tween.tween_property(_sub_label, "modulate:a", 1.0, 0.3).set_delay(0.28)

	_tween.set_parallel(false)
	_tween.tween_interval(HOLD_TIME)

	_tween.set_parallel(true)
	_tween.tween_property(_top_bar, "position:y", -thin, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_bottom_bar, "position:y", vp.y, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_code_label, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_title_label, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_sub_label, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_dim, "color:a", 0.0, 0.3).set_delay(0.15)

	_tween.set_parallel(false)
	_tween.tween_callback(_finish)
	await finished


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var pressed: bool = event is InputEventKey and event.pressed \
		or event is InputEventMouseButton and event.pressed \
		or event is InputEventScreenTouch and event.pressed \
		or event is InputEventJoypadButton and event.pressed
	if pressed:
		_skip()


func _skip() -> void:
	_playing = false
	if _tween and _tween.is_valid():
		_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "color:a", 0.0, 0.12)
	tween.tween_property(_code_label, "modulate:a", 0.0, 0.12)
	tween.tween_property(_title_label, "modulate:a", 0.0, 0.12)
	tween.tween_property(_sub_label, "modulate:a", 0.0, 0.12)
	tween.tween_property(_top_bar, "position:y", -_top_bar.size.y, 0.16)
	tween.tween_property(_bottom_bar, "position:y", _viewport_size().y, 0.16)
	tween.set_parallel(false)
	tween.tween_callback(_finish)


func _finish() -> void:
	_playing = false
	finished.emit()
	queue_free()
