@tool
class_name CCSAnimationSetEditor
extends HSplitContainer
## Shared animation authoring surface for the Hero / Customer / Enemy factory
## tabs: a zoomable sheet on the left, and on the right the standard animation
## set for that content type — assign the current frame selection to an
## animation, reorder frames, set FPS/loop, preview playback, and set pivot.
## Produces/consumes the runtime manifest format (SpriteFramesBuilder).

signal changed

var sheet_path: String = ""
## anim name -> {"rects": Array of [x,y,w,h], "fps": float, "loop": bool}
var animations: Dictionary = {}
var pivot := Vector2i(-1, -1)
var display_scale: float = 1.0

var required_names: Array[String] = []
var optional_names: Array[String] = []

var preview: CCSSpriteSheetPreview
var anim_player: CCSAnimationPreview

var _anim_option: OptionButton
var _frame_list: ItemList
var _pivot_x: SpinBox
var _pivot_y: SpinBox
var _scale_spin: SpinBox
var _status: Label


func _ready() -> void:
	split_offset = 520
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	preview = CCSSpriteSheetPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(preview)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	add_child(right)

	var anim_row := HBoxContainer.new()
	anim_row.add_child(_mk_label("Animation:"))
	_anim_option = OptionButton.new()
	_anim_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_option.item_selected.connect(func(_i: int) -> void: _refresh_frames())
	anim_row.add_child(_anim_option)
	right.add_child(anim_row)

	var assign_row := HBoxContainer.new()
	var assign_btn := Button.new()
	assign_btn.text = "Set = Selection"
	assign_btn.tooltip_text = "Replace this animation's frames with the sheet selection (in selection order)"
	assign_btn.pressed.connect(func() -> void: _assign_selection(false))
	assign_row.add_child(assign_btn)
	var append_btn := Button.new()
	append_btn.text = "Append Selection"
	append_btn.pressed.connect(func() -> void: _assign_selection(true))
	assign_row.add_child(append_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func() -> void:
		_current_spec()["rects"] = []
		_refresh_frames())
	assign_row.add_child(clear_btn)
	right.add_child(assign_row)

	_frame_list = ItemList.new()
	_frame_list.custom_minimum_size = Vector2(0, 90)
	_frame_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_frame_list)

	var order_row := HBoxContainer.new()
	for pair in [["Up", -1], ["Down", 1]]:
		var b := Button.new()
		b.text = "Move %s" % pair[0]
		b.pressed.connect(func() -> void: _move_frame(int(pair[1])))
		order_row.add_child(b)
	var del_btn := Button.new()
	del_btn.text = "Remove"
	del_btn.pressed.connect(_remove_frame)
	order_row.add_child(del_btn)
	right.add_child(order_row)

	anim_player = CCSAnimationPreview.new()
	anim_player.custom_minimum_size = Vector2(0, 170)
	anim_player.fps_changed.connect(func(v: float) -> void:
		_current_spec()["fps"] = v
		changed.emit())
	anim_player.loop_changed.connect(func(on: bool) -> void:
		_current_spec()["loop"] = on
		changed.emit())
	right.add_child(anim_player)

	var pivot_row := HBoxContainer.new()
	pivot_row.add_child(_mk_label("Pivot"))
	_pivot_x = _mk_spin(pivot_row, -512, 512, func(_v: float) -> void: _pivot_edited())
	_pivot_y = _mk_spin(pivot_row, -512, 512, func(_v: float) -> void: _pivot_edited())
	pivot_row.add_child(_mk_label("Scale"))
	_scale_spin = _mk_spin(pivot_row, 0.25, 8.0, func(v: float) -> void:
		display_scale = v
		changed.emit())
	_scale_spin.step = 0.25
	_scale_spin.set_value_no_signal(1.0)
	right.add_child(pivot_row)

	_status = _mk_label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_status)

	preview.selection_changed.connect(func() -> void:
		_status.text = "%d frame(s) selected on sheet" % preview.selected_rects.size())


func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _mk_spin(row: HBoxContainer, min_v: float, max_v: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1
	s.value_changed.connect(cb)
	row.add_child(s)
	return s


func set_animation_names(required: Array[String], optional: Array[String]) -> void:
	required_names = required
	optional_names = optional
	_anim_option.clear()
	for n in required:
		_anim_option.add_item(n)
	for n in optional:
		_anim_option.add_item("%s (optional)" % n)
	if _anim_option.item_count > 0:
		_anim_option.select(0)
	_refresh_frames()


func current_animation_name() -> String:
	if _anim_option.selected < 0:
		return ""
	var idx := _anim_option.selected
	if idx < required_names.size():
		return required_names[idx]
	return optional_names[idx - required_names.size()]


func load_sheet(res_path: String) -> String:
	var err := preview.load_sheet(res_path)
	if err == "":
		sheet_path = res_path
	return err


func clear_animations() -> void:
	animations.clear()
	pivot = Vector2i(-1, -1)
	display_scale = 1.0
	_scale_spin.set_value_no_signal(1.0)
	_refresh_frames()


func _current_spec() -> Dictionary:
	var name := current_animation_name()
	if name == "":
		return {}
	if not animations.has(name):
		animations[name] = {"rects": [], "fps": 6.0, "loop": true}
	return animations[name]


func _assign_selection(append: bool) -> void:
	var sel := preview.get_selected_rects()
	if sel.is_empty():
		_status.text = "Nothing selected on the sheet — click or drag frames first."
		return
	var spec := _current_spec()
	if spec.is_empty():
		return
	var rects: Array = spec["rects"] if append else []
	for r in sel:
		rects.append([r.position.x, r.position.y, r.size.x, r.size.y])
	spec["rects"] = rects
	# a sensible default pivot: bottom-center of the first assigned frame
	if pivot.x < 0 and not rects.is_empty():
		pivot = Vector2i(int(rects[0][2]) / 2, int(rects[0][3]) - 4)
		_pivot_x.set_value_no_signal(pivot.x)
		_pivot_y.set_value_no_signal(pivot.y)
	_refresh_frames()
	changed.emit()


func _refresh_frames() -> void:
	_frame_list.clear()
	var spec := _current_spec()
	if spec.is_empty():
		return
	for r in spec.get("rects", []):
		_frame_list.add_item("(%d, %d, %d, %d)" % [int(r[0]), int(r[1]), int(r[2]), int(r[3])])
	anim_player.set_frames(preview.texture, _spec_rects(spec), float(spec.get("fps", 6.0)), bool(spec.get("loop", true)))


func _spec_rects(spec: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r in spec.get("rects", []):
		out.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	return out


func _move_frame(dir: int) -> void:
	var sel := _frame_list.get_selected_items()
	if sel.is_empty():
		return
	var i := sel[0]
	var rects: Array = _current_spec().get("rects", [])
	var j := i + dir
	if j < 0 or j >= rects.size():
		return
	var tmp: Variant = rects[i]
	rects[i] = rects[j]
	rects[j] = tmp
	_refresh_frames()
	_frame_list.select(j)
	changed.emit()


func _remove_frame() -> void:
	var sel := _frame_list.get_selected_items()
	if sel.is_empty():
		return
	var rects: Array = _current_spec().get("rects", [])
	rects.remove_at(sel[0])
	_refresh_frames()
	changed.emit()


func _pivot_edited() -> void:
	pivot = Vector2i(int(_pivot_x.value), int(_pivot_y.value))
	changed.emit()


func missing_required() -> Array[String]:
	var out: Array[String] = []
	for n in required_names:
		var spec: Dictionary = animations.get(n, {})
		if (spec.get("rects", []) as Array).is_empty():
			out.append(n)
	return out


func frame_cell() -> Vector2i:
	# the manifest grid block wants one nominal frame size; use the largest
	# assigned rect so pivot/offset math stays sane for mixed sizes
	var cell := Vector2i.ZERO
	for name: String in animations:
		for r in (animations[name] as Dictionary).get("rects", []):
			cell.x = maxi(cell.x, int(r[2]))
			cell.y = maxi(cell.y, int(r[3]))
	if cell == Vector2i.ZERO:
		cell = preview.frame_size
	return cell


## Builds the runtime manifest (SpriteFramesBuilder schema, rects form).
func build_manifest(entity_id: String, sheet_dest: String) -> Dictionary:
	var cell := frame_cell()
	var pv := pivot
	if pv.x < 0:
		pv = Vector2i(cell.x / 2, cell.y - 4)
	var anims := {}
	for name: String in animations:
		var spec: Dictionary = animations[name]
		if (spec.get("rects", []) as Array).is_empty():
			continue
		anims[name] = {
			"rects": (spec["rects"] as Array).duplicate(true),
			"fps": float(spec.get("fps", 6.0)),
			"loop": bool(spec.get("loop", true)),
		}
	return {
		"asset_id": entity_id,
		"sheet": sheet_dest,
		"native_scale": 1,
		"display_scale": display_scale,
		"pivot": [pv.x, pv.y],
		"grid": {
			"frame_width": cell.x, "frame_height": cell.y,
			"columns": preview.grid_columns() if preview.grid_columns() > 0 else 1,
			"rows": preview.grid_rows() if preview.grid_rows() > 0 else 1,
		},
		"animations": anims,
	}


## Loads an existing manifest back into the editor (frames indices are
## converted to rects using the manifest grid).
func load_manifest(manifest: Dictionary) -> void:
	clear_animations()
	var grid: Dictionary = manifest.get("grid", {})
	var fw := int(grid.get("frame_width", 32))
	var fh := int(grid.get("frame_height", 32))
	var cols := int(grid.get("columns", 1))
	preview.set_grid(fw, fh)
	var pv: Array = manifest.get("pivot", [-1, -1])
	pivot = Vector2i(int(pv[0]), int(pv[1]))
	_pivot_x.set_value_no_signal(pivot.x)
	_pivot_y.set_value_no_signal(pivot.y)
	display_scale = float(manifest.get("display_scale", 1.0))
	_scale_spin.set_value_no_signal(display_scale)
	for name: String in manifest.get("animations", {}):
		var spec: Dictionary = manifest["animations"][name]
		var rects: Array = []
		for r in spec.get("rects", []):
			rects.append([int(r[0]), int(r[1]), int(r[2]), int(r[3])])
		for idx in spec.get("frames", []):
			var i := int(idx)
			rects.append([(i % cols) * fw, (i / cols) * fh, fw, fh])
		animations[name] = {
			"rects": rects,
			"fps": float(spec.get("fps", 6.0)),
			"loop": bool(spec.get("loop", true)),
		}
	_refresh_frames()
