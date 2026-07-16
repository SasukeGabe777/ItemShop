@tool
class_name CCSAnimationPreview
extends VBoxContainer
## Small animation playback widget shared by the Hero/Customer/Enemy factory
## tabs: plays an ordered list of source-sheet regions at a chosen FPS with
## nearest-neighbor scaling. Play/stop, single-frame stepping, loop toggle,
## and a preview scale selector. Purely visual — owns no data.

signal fps_changed(fps: float)
signal loop_changed(loop: bool)

var fps: float = 8.0
var looping := true

var _texture: Texture2D
var _rects: Array[Rect2i] = []
var _frame: int = 0
var _playing := false
var _accum: float = 0.0
var _preview_scale: float = 4.0

var _view: Control
var _play_btn: Button
var _frame_label: Label
var _fps_spin: SpinBox
var _loop_check: CheckBox


func _ready() -> void:
	_build_ui()
	set_process(false)


func _build_ui() -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.pressed.connect(_toggle_play)
	bar.add_child(_play_btn)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.tooltip_text = "Previous frame"
	prev_btn.pressed.connect(func() -> void: _step(-1))
	bar.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.tooltip_text = "Next frame"
	next_btn.pressed.connect(func() -> void: _step(1))
	bar.add_child(next_btn)

	var fps_label := Label.new()
	fps_label.text = "FPS"
	bar.add_child(fps_label)
	_fps_spin = SpinBox.new()
	_fps_spin.min_value = 1
	_fps_spin.max_value = 60
	_fps_spin.step = 1
	_fps_spin.value = fps
	_fps_spin.value_changed.connect(func(v: float) -> void:
		fps = v
		fps_changed.emit(v))
	bar.add_child(_fps_spin)

	_loop_check = CheckBox.new()
	_loop_check.text = "Loop"
	_loop_check.button_pressed = looping
	_loop_check.toggled.connect(func(on: bool) -> void:
		looping = on
		loop_changed.emit(on))
	bar.add_child(_loop_check)

	var scale_option := OptionButton.new()
	for s in [1, 2, 4, 8]:
		scale_option.add_item("%dx" % s)
	scale_option.selected = 2
	scale_option.item_selected.connect(func(i: int) -> void:
		_preview_scale = float([1, 2, 4, 8][i])
		_view.queue_redraw())
	bar.add_child(scale_option)

	_frame_label = Label.new()
	_frame_label.text = ""
	bar.add_child(_frame_label)

	_view = Control.new()
	_view.clip_contents = true
	_view.custom_minimum_size = Vector2(160, 140)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_view)
	add_child(_view)


func set_frames(texture: Texture2D, rects: Array[Rect2i], p_fps: float = -1.0, p_loop: Variant = null) -> void:
	_texture = texture
	_rects = rects.duplicate()
	_frame = 0
	_accum = 0.0
	if p_fps > 0.0:
		fps = p_fps
		if _fps_spin != null:
			_fps_spin.set_value_no_signal(p_fps)
	if p_loop != null:
		looping = bool(p_loop)
		if _loop_check != null:
			_loop_check.set_pressed_no_signal(looping)
	if _rects.is_empty():
		stop()
	_update_frame_label()
	if _view != null:
		_view.queue_redraw()


func play() -> void:
	if _rects.is_empty():
		return
	_playing = true
	_play_btn.text = "Stop"
	set_process(true)


func stop() -> void:
	_playing = false
	if _play_btn != null:
		_play_btn.text = "Play"
	set_process(false)


func _toggle_play() -> void:
	if _playing:
		stop()
	else:
		play()


func _step(dir: int) -> void:
	if _rects.is_empty():
		return
	stop()
	_frame = wrapi(_frame + dir, 0, _rects.size())
	_update_frame_label()
	_view.queue_redraw()


func _process(delta: float) -> void:
	if not _playing or _rects.is_empty():
		return
	_accum += delta
	var step_time := 1.0 / maxf(1.0, fps)
	while _accum >= step_time:
		_accum -= step_time
		_frame += 1
		if _frame >= _rects.size():
			if looping:
				_frame = 0
			else:
				_frame = _rects.size() - 1
				stop()
				break
	_update_frame_label()
	_view.queue_redraw()


func _update_frame_label() -> void:
	if _frame_label == null:
		return
	_frame_label.text = "" if _rects.is_empty() else "%d / %d" % [_frame + 1, _rects.size()]


func _draw_view() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.12, 0.12, 0.14))
	if _texture == null or _rects.is_empty():
		return
	var r := _rects[clampi(_frame, 0, _rects.size() - 1)]
	var draw_size := Vector2(r.size) * _preview_scale
	var pos := (_view.size - draw_size) * 0.5
	_view.draw_texture_rect_region(_texture, Rect2(pos, draw_size), Rect2(r))
	_view.draw_rect(Rect2(pos, draw_size), Color(1, 1, 1, 0.15), false, 1.0)
