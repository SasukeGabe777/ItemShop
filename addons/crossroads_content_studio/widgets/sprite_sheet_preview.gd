@tool
class_name CCSSpriteSheetPreview
extends VBoxContainer
## Reusable Aseprite-style sheet viewer for the Asset Factory tabs: pixel-
## perfect (nearest-neighbor) zoom/pan, configurable frame grid, click and
## drag-rectangle frame selection, and frame extraction helpers. Selection is
## an ordered list of pixel Rect2i regions so animation tabs can use selection
## order as frame order. Preview-only — never modifies or re-saves the source.

signal selection_changed
signal frame_activated(rect: Rect2i)

const ZOOM_LEVELS: Array[float] = [0.125, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0]

var texture: Texture2D
var image: Image
var source_path: String = ""

var grid_enabled := true
var frame_size := Vector2i(32, 32)
var grid_margin := Vector2i.ZERO
var grid_spacing := Vector2i.ZERO

## Background (chroma-key) removal. Auto-enabled when a loaded sheet has no
## transparency at all — those rips almost always sit on a flat canvas color.
## Applied to the preview AND to every exported frame/sheet; the raw source
## file itself is never modified.
var chroma_enabled := false
var chroma_color := Color(1, 0, 1)
var chroma_tolerance := 0.02

var _processed: Image
var _chroma_check: CheckBox
var _chroma_picker: ColorPickerButton
var _chroma_tol_spin: SpinBox

## Ordered selection: Array of Rect2i (pixel regions in the source image).
var selected_rects: Array[Rect2i] = []

var _canvas: Control
var _status: Label
var _grid_check: CheckBox
var _fw_spin: SpinBox
var _fh_spin: SpinBox
var _margin_spin: SpinBox
var _spacing_spin: SpinBox
var _zoom_label: Label

var _zoom: float = 2.0
var _offset := Vector2.ZERO
var _panning := false
var _pan_start := Vector2.ZERO
var _offset_start := Vector2.ZERO
var _dragging := false
var _drag_from := Vector2.ZERO
var _drag_to := Vector2.ZERO


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	var zoom_out := Button.new()
	zoom_out.text = "-"
	zoom_out.tooltip_text = "Zoom out"
	zoom_out.pressed.connect(func() -> void: _step_zoom(-1))
	bar.add_child(zoom_out)

	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size = Vector2(52, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_zoom_label)

	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoom in"
	zoom_in.pressed.connect(func() -> void: _step_zoom(1))
	bar.add_child(zoom_in)

	var fit_btn := Button.new()
	fit_btn.text = "Fit"
	fit_btn.pressed.connect(fit_to_view)
	bar.add_child(fit_btn)

	var one_btn := Button.new()
	one_btn.text = "1:1"
	one_btn.pressed.connect(func() -> void: _set_zoom(1.0))
	bar.add_child(one_btn)

	bar.add_child(VSeparator.new())

	_grid_check = CheckBox.new()
	_grid_check.text = "Grid"
	_grid_check.button_pressed = grid_enabled
	_grid_check.tooltip_text = "On: click/drag selects whole grid cells. Off: drag selects free pixel rectangles."
	_grid_check.toggled.connect(func(on: bool) -> void:
		grid_enabled = on
		_redraw())
	bar.add_child(_grid_check)

	_fw_spin = _spin(bar, "W", frame_size.x, 1, 1024, func(v: float) -> void:
		frame_size.x = int(v)
		_redraw())
	_fh_spin = _spin(bar, "H", frame_size.y, 1, 1024, func(v: float) -> void:
		frame_size.y = int(v)
		_redraw())
	_margin_spin = _spin(bar, "Margin", grid_margin.x, 0, 512, func(v: float) -> void:
		grid_margin = Vector2i(int(v), int(v))
		_redraw())
	_spacing_spin = _spin(bar, "Spacing", grid_spacing.x, 0, 512, func(v: float) -> void:
		grid_spacing = Vector2i(int(v), int(v))
		_redraw())

	var clear_btn := Button.new()
	clear_btn.text = "Clear Selection"
	clear_btn.pressed.connect(clear_selection)
	bar.add_child(clear_btn)

	bar.add_child(VSeparator.new())

	_chroma_check = CheckBox.new()
	_chroma_check.text = "Remove BG"
	_chroma_check.tooltip_text = "Turn the background color transparent in the preview and in every exported frame.\nAuto-enabled for sheets with no transparency. Alt+click the sheet to sample the color."
	_chroma_check.toggled.connect(func(on: bool) -> void:
		chroma_enabled = on
		_rebuild_processed())
	bar.add_child(_chroma_check)

	_chroma_picker = ColorPickerButton.new()
	_chroma_picker.custom_minimum_size = Vector2(34, 0)
	_chroma_picker.color = chroma_color
	_chroma_picker.tooltip_text = "Background color to remove (Alt+click the sheet to sample it)"
	_chroma_picker.popup_closed.connect(func() -> void:
		chroma_color = _chroma_picker.color
		_rebuild_processed())
	bar.add_child(_chroma_picker)

	_chroma_tol_spin = SpinBox.new()
	_chroma_tol_spin.min_value = 0
	_chroma_tol_spin.max_value = 64
	_chroma_tol_spin.step = 1
	_chroma_tol_spin.value = roundf(chroma_tolerance * 255.0)
	_chroma_tol_spin.tooltip_text = "Tolerance (0-64, per channel out of 255)"
	_chroma_tol_spin.value_changed.connect(func(v: float) -> void:
		chroma_tolerance = v / 255.0
		_rebuild_processed())
	bar.add_child(_chroma_tol_spin)

	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.focus_mode = Control.FOCUS_CLICK
	_canvas.custom_minimum_size = Vector2(320, 240)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	add_child(_canvas)

	_status = Label.new()
	_status.text = "No sheet loaded."
	add_child(_status)
	_update_zoom_label()


func _spin(bar: HBoxContainer, label_text: String, value: float, min_v: float, max_v: float, on_change: Callable) -> SpinBox:
	var l := Label.new()
	l.text = label_text
	bar.add_child(l)
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1
	s.value = value
	s.value_changed.connect(on_change)
	bar.add_child(s)
	return s


## Loads a sheet directly from disk (works for raw files regardless of Godot
## import status). Returns "" on success or an error message.
func load_sheet(res_path: String) -> String:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		return "could not load image: %s (%s)" % [res_path, error_string(err)]
	img.convert(Image.FORMAT_RGBA8)
	image = img
	source_path = res_path
	_auto_detect_background()
	_rebuild_processed()
	clear_selection()
	fit_to_view()
	var note := " — background %s auto-keyed" % ("#" + chroma_color.to_html(false)) if chroma_enabled else ""
	_status.text = "%s — %dx%d%s" % [res_path.get_file(), img.get_width(), img.get_height(), note]
	return ""


## Sheets with zero transparent pixels are almost always rips sitting on a
## flat canvas color: sample the four corners and key the majority color.
func _auto_detect_background() -> void:
	chroma_enabled = false
	if image.detect_alpha() == Image.ALPHA_NONE:
		var w := image.get_width()
		var h := image.get_height()
		var corners: Array[Color] = [
			image.get_pixel(0, 0), image.get_pixel(w - 1, 0),
			image.get_pixel(0, h - 1), image.get_pixel(w - 1, h - 1),
		]
		var best := corners[0]
		var best_count := 0
		for c in corners:
			var count := 0
			for other in corners:
				if c.is_equal_approx(other):
					count += 1
			if count > best_count:
				best_count = count
				best = c
		chroma_color = best
		chroma_enabled = true
	if _chroma_check != null:
		_chroma_check.set_pressed_no_signal(chroma_enabled)
		_chroma_picker.color = chroma_color


## The image every draw and export actually uses: chroma-keyed when enabled.
func processed_image() -> Image:
	return _processed if _processed != null else image


func _rebuild_processed() -> void:
	if image == null:
		_processed = null
		return
	if not chroma_enabled:
		_processed = image
	else:
		_processed = chroma_keyed(image, chroma_color, chroma_tolerance)
	texture = ImageTexture.create_from_image(_processed)
	_redraw()


static func chroma_keyed(src: Image, key: Color, tolerance: float) -> Image:
	var out := src.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var p := out.get_pixel(x, y)
			if absf(p.r - key.r) <= tolerance and absf(p.g - key.g) <= tolerance and absf(p.b - key.b) <= tolerance:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out


## Sidecar-friendly record of how exports were produced.
func chroma_meta() -> Dictionary:
	if not chroma_enabled:
		return {}
	return {"chroma_key": "#" + chroma_color.to_html(false), "chroma_tolerance": chroma_tolerance}


## Export one region as PNG, honoring the background-removal settings.
func export_region_png(rect: Rect2i, dest_res_path: String) -> String:
	return save_region_png(processed_image(), rect, dest_res_path)


## Export regions as a packed horizontal strip, honoring background removal.
func export_strip_png(rects: Array[Rect2i], dest_res_path: String) -> String:
	return save_strip_png(processed_image(), rects, dest_res_path)


## Export the whole sheet (background removed when enabled) — used when a
## manifest needs a processed copy of the full sheet.
func export_sheet_png(dest_res_path: String) -> String:
	if image == null:
		return "no sheet loaded"
	CCSFileOps.ensure_dir(dest_res_path.get_base_dir())
	var err := processed_image().save_png(ProjectSettings.globalize_path(dest_res_path))
	if err != OK:
		return "failed to save %s (%s)" % [dest_res_path, error_string(err)]
	return ""


func set_grid(fw: int, fh: int, margin: int = 0, spacing: int = 0) -> void:
	frame_size = Vector2i(maxi(1, fw), maxi(1, fh))
	grid_margin = Vector2i(margin, margin)
	grid_spacing = Vector2i(spacing, spacing)
	if _fw_spin != null:
		_fw_spin.set_value_no_signal(frame_size.x)
		_fh_spin.set_value_no_signal(frame_size.y)
		_margin_spin.set_value_no_signal(margin)
		_spacing_spin.set_value_no_signal(spacing)
	_redraw()


func clear_selection() -> void:
	selected_rects.clear()
	_redraw()
	selection_changed.emit()


func get_selected_rects() -> Array[Rect2i]:
	return selected_rects.duplicate()


func grid_columns() -> int:
	if image == null or frame_size.x <= 0:
		return 0
	var usable := image.get_width() - grid_margin.x
	return maxi(0, (usable + grid_spacing.x) / (frame_size.x + grid_spacing.x))


func grid_rows() -> int:
	if image == null or frame_size.y <= 0:
		return 0
	var usable := image.get_height() - grid_margin.y
	return maxi(0, (usable + grid_spacing.y) / (frame_size.y + grid_spacing.y))


func frame_rect(index: int) -> Rect2i:
	var cols := grid_columns()
	if cols <= 0:
		return Rect2i()
	var col := index % cols
	var row := index / cols
	return Rect2i(
		grid_margin.x + col * (frame_size.x + grid_spacing.x),
		grid_margin.y + row * (frame_size.y + grid_spacing.y),
		frame_size.x, frame_size.y)


func frame_index_at(image_pos: Vector2i) -> int:
	var cols := grid_columns()
	if cols <= 0:
		return -1
	var rel := image_pos - grid_margin
	if rel.x < 0 or rel.y < 0:
		return -1
	var col := rel.x / (frame_size.x + grid_spacing.x)
	var row := rel.y / (frame_size.y + grid_spacing.y)
	if col >= cols or row >= grid_rows():
		return -1
	if not frame_rect(row * cols + col).has_point(image_pos):
		return -1
	return row * cols + col


func fit_to_view() -> void:
	if image == null or _canvas == null:
		return
	var view := _canvas.size
	if view.x < 8 or view.y < 8:
		view = _canvas.custom_minimum_size
	var sx := view.x / float(image.get_width())
	var sy := view.y / float(image.get_height())
	_zoom = clampf(minf(sx, sy) * 0.95, ZOOM_LEVELS[0], ZOOM_LEVELS[-1])
	_offset = (view - Vector2(image.get_size()) * _zoom) * 0.5
	_update_zoom_label()
	_redraw()


func _set_zoom(z: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	var old := _zoom
	_zoom = clampf(z, ZOOM_LEVELS[0], ZOOM_LEVELS[-1])
	if pivot.x < 0:
		pivot = _canvas.size * 0.5
	_offset = pivot - (pivot - _offset) * (_zoom / old)
	_update_zoom_label()
	_redraw()


func _step_zoom(dir: int, pivot: Vector2 = Vector2(-1, -1)) -> void:
	var idx := 0
	var best := INF
	for i in ZOOM_LEVELS.size():
		var d := absf(ZOOM_LEVELS[i] - _zoom)
		if d < best:
			best = d
			idx = i
	idx = clampi(idx + dir, 0, ZOOM_LEVELS.size() - 1)
	_set_zoom(ZOOM_LEVELS[idx], pivot)


func _update_zoom_label() -> void:
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % int(round(_zoom * 100.0))


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _canvas_to_image(pos: Vector2) -> Vector2:
	return (pos - _offset) / _zoom


func _image_to_canvas_rect(r: Rect2i) -> Rect2:
	return Rect2(_offset + Vector2(r.position) * _zoom, Vector2(r.size) * _zoom)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_step_zoom(1, mb.position)
			_canvas.accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_step_zoom(-1, mb.position)
			_canvas.accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_pan_start = mb.position
			_offset_start = _offset
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.alt_pressed:
				_sample_background(mb.position)
			elif mb.pressed:
				_dragging = true
				_drag_from = mb.position
				_drag_to = mb.position
			elif _dragging:
				_dragging = false
				_finish_drag(mb)
			_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_offset = _offset_start + (mm.position - _pan_start)
			_redraw()
		elif _dragging:
			_drag_to = mm.position
			_redraw()
		_update_hover_status(mm.position)


## Alt+click: sample the clicked pixel (from the ORIGINAL image, so an
## already-keyed color can be re-picked) as the background key color.
func _sample_background(canvas_pos: Vector2) -> void:
	if image == null:
		return
	var ip := Vector2i(_canvas_to_image(canvas_pos).floor())
	if ip.x < 0 or ip.y < 0 or ip.x >= image.get_width() or ip.y >= image.get_height():
		return
	chroma_color = image.get_pixel(ip.x, ip.y)
	chroma_enabled = true
	if _chroma_check != null:
		_chroma_check.set_pressed_no_signal(true)
		_chroma_picker.color = chroma_color
	_rebuild_processed()
	_status.text = "Background key sampled: #%s" % chroma_color.to_html(false)


func _update_hover_status(canvas_pos: Vector2) -> void:
	if image == null:
		return
	var ip := Vector2i(_canvas_to_image(canvas_pos).floor())
	var parts: Array[String] = ["px (%d, %d)" % [ip.x, ip.y]]
	if grid_enabled:
		var idx := frame_index_at(ip)
		if idx >= 0:
			var r := frame_rect(idx)
			parts.append("frame %d — rect (%d, %d, %d, %d)" % [idx, r.position.x, r.position.y, r.size.x, r.size.y])
	if not selected_rects.is_empty():
		parts.append("%d selected" % selected_rects.size())
	_status.text = " | ".join(parts)


func _finish_drag(mb: InputEventMouseButton) -> void:
	if image == null:
		return
	var moved := _drag_from.distance_to(_drag_to) > 4.0
	var additive := mb.shift_pressed or mb.ctrl_pressed
	if grid_enabled:
		if moved:
			_select_grid_range(_drag_from, _drag_to, additive)
		else:
			_toggle_grid_cell(_drag_from, additive, mb.double_click)
	else:
		if moved:
			_select_free_rect(_drag_from, _drag_to, additive)
		else:
			_click_free(_drag_from, additive)
	selection_changed.emit()
	_redraw()


func _toggle_grid_cell(canvas_pos: Vector2, additive: bool, activated: bool) -> void:
	var idx := frame_index_at(Vector2i(_canvas_to_image(canvas_pos).floor()))
	if idx < 0:
		if not additive:
			selected_rects.clear()
		return
	var r := frame_rect(idx)
	if activated:
		frame_activated.emit(r)
		return
	var at := selected_rects.find(r)
	if additive:
		if at >= 0:
			selected_rects.remove_at(at)
		else:
			selected_rects.append(r)
	else:
		if at >= 0 and selected_rects.size() == 1:
			selected_rects.clear()
		else:
			selected_rects = [r] as Array[Rect2i]


func _select_grid_range(from_c: Vector2, to_c: Vector2, additive: bool) -> void:
	if not additive:
		selected_rects.clear()
	var a := _canvas_to_image(from_c)
	var b := _canvas_to_image(to_c)
	var top_left := Vector2i(Vector2(minf(a.x, b.x), minf(a.y, b.y)).floor())
	var bottom_right := Vector2i(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)).floor())
	var cols := grid_columns()
	if cols <= 0:
		return
	# Row-major sweep so drag selection produces a stable frame order.
	for row in grid_rows():
		for col in cols:
			var r := frame_rect(row * cols + col)
			if r.intersects(Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)) and not selected_rects.has(r):
				selected_rects.append(r)


func _select_free_rect(from_c: Vector2, to_c: Vector2, additive: bool) -> void:
	if not additive:
		selected_rects.clear()
	var a := _canvas_to_image(from_c).floor()
	var b := _canvas_to_image(to_c).floor()
	var pos := Vector2i(int(minf(a.x, b.x)), int(minf(a.y, b.y)))
	var end := Vector2i(int(maxf(a.x, b.x)) + 1, int(maxf(a.y, b.y)) + 1)
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var r := Rect2i(pos, end - pos).intersection(bounds)
	if r.size.x > 0 and r.size.y > 0:
		selected_rects.append(r)


func _click_free(canvas_pos: Vector2, additive: bool) -> void:
	var ip := Vector2i(_canvas_to_image(canvas_pos).floor())
	for i in range(selected_rects.size() - 1, -1, -1):
		if selected_rects[i].has_point(ip):
			selected_rects.remove_at(i)
			return
	if not additive:
		selected_rects.clear()


func _draw_canvas() -> void:
	var view := Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_rect(view, Color(0.12, 0.12, 0.14))
	if texture == null:
		return
	var img_rect := Rect2(_offset, Vector2(image.get_size()) * _zoom)
	_draw_checker(img_rect.intersection(view))
	_canvas.draw_texture_rect(texture, img_rect, false)
	_canvas.draw_rect(img_rect, Color(1, 1, 1, 0.25), false, 1.0)

	if grid_enabled and image != null:
		_draw_grid()

	var sel_fill := Color(0.3, 0.7, 1.0, 0.25)
	var sel_border := Color(0.4, 0.8, 1.0, 0.9)
	var font := get_theme_default_font()
	for i in selected_rects.size():
		var cr := _image_to_canvas_rect(selected_rects[i])
		_canvas.draw_rect(cr, sel_fill)
		_canvas.draw_rect(cr, sel_border, false, 2.0)
		if cr.size.x > 18 and cr.size.y > 14:
			_canvas.draw_string(font, cr.position + Vector2(3, 13), str(i),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))

	if _dragging:
		var pos := Vector2(minf(_drag_from.x, _drag_to.x), minf(_drag_from.y, _drag_to.y))
		var end := Vector2(maxf(_drag_from.x, _drag_to.x), maxf(_drag_from.y, _drag_to.y))
		var dr := Rect2(pos, end - pos)
		_canvas.draw_rect(dr, Color(1, 1, 0.4, 0.12))
		_canvas.draw_rect(dr, Color(1, 1, 0.4, 0.8), false, 1.0)


func _draw_checker(area: Rect2) -> void:
	if area.size.x <= 0 or area.size.y <= 0:
		return
	_canvas.draw_rect(area, Color(0.22, 0.22, 0.25))
	var cell := 12.0
	var start_x := floorf(area.position.x / cell) * cell
	var start_y := floorf(area.position.y / cell) * cell
	var y := start_y
	while y < area.end.y:
		var x := start_x
		while x < area.end.x:
			if int(x / cell + y / cell) % 2 == 0:
				var r := Rect2(x, y, cell, cell).intersection(area)
				if r.size.x > 0 and r.size.y > 0:
					_canvas.draw_rect(r, Color(0.28, 0.28, 0.31))
			x += cell
		y += cell


func _draw_grid() -> void:
	var cols := grid_columns()
	var rows := grid_rows()
	if cols <= 0 or rows <= 0:
		return
	var line := Color(1, 1, 1, 0.18)
	var font := get_theme_default_font()
	var show_labels := _zoom * frame_size.x >= 26.0 and _zoom * frame_size.y >= 18.0
	for row in rows:
		for col in cols:
			var idx := row * cols + col
			var cr := _image_to_canvas_rect(frame_rect(idx))
			_canvas.draw_rect(cr, line, false, 1.0)
			if show_labels and not selected_rects.has(frame_rect(idx)):
				_canvas.draw_string(font, cr.position + Vector2(3, 13), str(idx),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))


## --- Frame extraction helpers (shared by all factory tabs) -----------------


static func extract_region(src: Image, rect: Rect2i) -> Image:
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	return src.get_region(bounded)


## Saves one selected region as its own PNG. Returns "" or an error message.
static func save_region_png(src: Image, rect: Rect2i, dest_res_path: String) -> String:
	if src == null:
		return "no source image"
	CCSFileOps.ensure_dir(dest_res_path.get_base_dir())
	var err := extract_region(src, rect).save_png(ProjectSettings.globalize_path(dest_res_path))
	if err != OK:
		return "failed to save %s (%s)" % [dest_res_path, error_string(err)]
	return ""


## Packs regions into a horizontal strip (cells sized to the largest region,
## content top-left anchored) and saves it. Returns "" or an error message.
static func save_strip_png(src: Image, rects: Array[Rect2i], dest_res_path: String) -> String:
	if src == null or rects.is_empty():
		return "nothing selected"
	var cell := Vector2i.ZERO
	for r in rects:
		cell.x = maxi(cell.x, r.size.x)
		cell.y = maxi(cell.y, r.size.y)
	var strip := Image.create(cell.x * rects.size(), cell.y, false, Image.FORMAT_RGBA8)
	for i in rects.size():
		var region := extract_region(src, rects[i])
		strip.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), Vector2i(cell.x * i, 0))
	CCSFileOps.ensure_dir(dest_res_path.get_base_dir())
	var err := strip.save_png(ProjectSettings.globalize_path(dest_res_path))
	if err != OK:
		return "failed to save %s (%s)" % [dest_res_path, error_string(err)]
	return ""
