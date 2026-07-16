extends Control
## Sprite-sheet import utility (run scene: tools/sprite_importer/sprite_importer.tscn,
## or `godot --path . res://tools/sprite_importer/sprite_importer.tscn`).
##
## Supports: PNG/GIF-frame sheets, chroma-key removal, fixed grid slicing,
## variable rect slicing, per-animation naming/fps/loop, pivot, display scale,
## flip preview, collision-box preview, atlas export, SpriteFrames .tres export
## and manifest JSON save/load compatible with SpriteFramesBuilder.
##
## CLI batch mode:
##   godot --headless --path . res://tools/sprite_importer/sprite_importer.tscn \
##     -- --manifest path/to/manifest.json --out res://assets/.../processed/name.tres

var sheet_image: Image
var sheet_texture: ImageTexture
var sheet_path_edit: LineEdit
var chroma_edit: LineEdit
var grid_w: SpinBox
var grid_h: SpinBox
var scale_spin: SpinBox
var pivot_x: SpinBox
var pivot_y: SpinBox
var anim_name_edit: LineEdit
var frames_edit: LineEdit
var fps_spin: SpinBox
var loop_check: CheckBox
var flip_check: CheckBox
var collision_check: CheckBox
var anim_list: ItemList
var preview_sprite: AnimatedSprite2D
var preview_holder: Node2D
var grid_overlay: Control
var status: Label
var animations: Dictionary = {}  # name -> {frames, fps, loop}
var manifest_path: String = ""


func _ready() -> void:
	# headless batch mode
	var args := OS.get_cmdline_user_args()
	if "--manifest" in args:
		_run_batch(args)
		return
	_build_ui()


func _run_batch(args: PackedStringArray) -> void:
	var mpath := ""
	var out := ""
	for i in range(args.size()):
		if args[i] == "--manifest" and i + 1 < args.size():
			mpath = args[i + 1]
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	var frames := SpriteFramesBuilder.from_manifest_path(mpath)
	if frames == null:
		printerr("IMPORTER_FAIL: cannot build from %s" % mpath)
		get_tree().quit(1)
		return
	if out == "":
		out = mpath.get_basename() + ".tres"
	var err := ResourceSaver.save(frames, out)
	print("IMPORTER_OK: %s -> %s (%d animations)" % [mpath, out, frames.get_animation_names().size()] if err == OK else "IMPORTER_FAIL: save error %d" % err)
	get_tree().quit(0 if err == OK else 1)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIKit.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var left := UIKit.panel(Vector2(330, 0))
	root.add_child(left)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	left.add_child(vb)
	vb.add_child(UIKit.header("Sprite Importer"))
	vb.add_child(UIKit.label("Sheet path (png; gif via frame PNGs):", 9))
	sheet_path_edit = LineEdit.new()
	sheet_path_edit.text = "res://assets/hero/raw/hero_faraway_overworld.png"
	vb.add_child(sheet_path_edit)
	vb.add_child(UIKit.button("Load sheet", _load_sheet))
	vb.add_child(UIKit.label("Chroma key (hex, empty = use alpha):", 9))
	chroma_edit = LineEdit.new()
	chroma_edit.placeholder_text = "#ff00ff"
	vb.add_child(chroma_edit)
	var grid_row := HBoxContainer.new()
	grid_row.add_child(UIKit.label("Grid W/H:", 9))
	grid_w = SpinBox.new(); grid_w.min_value = 1; grid_w.max_value = 512; grid_w.value = 32
	grid_h = SpinBox.new(); grid_h.min_value = 1; grid_h.max_value = 512; grid_h.value = 32
	grid_row.add_child(grid_w)
	grid_row.add_child(grid_h)
	vb.add_child(grid_row)
	var pivot_row := HBoxContainer.new()
	pivot_row.add_child(UIKit.label("Pivot:", 9))
	pivot_x = SpinBox.new(); pivot_x.min_value = -256; pivot_x.max_value = 256; pivot_x.value = 16
	pivot_y = SpinBox.new(); pivot_y.min_value = -256; pivot_y.max_value = 256; pivot_y.value = 28
	pivot_row.add_child(pivot_x)
	pivot_row.add_child(pivot_y)
	var scale_lbl := UIKit.label("Scale:", 9)
	pivot_row.add_child(scale_lbl)
	scale_spin = SpinBox.new(); scale_spin.min_value = 1; scale_spin.max_value = 8; scale_spin.value = 3
	pivot_row.add_child(scale_spin)
	vb.add_child(pivot_row)
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.label("Animation name / frames (e.g. 0,1,2,1 or rects x,y,w,h;...):", 9))
	anim_name_edit = LineEdit.new()
	anim_name_edit.text = "walk_down"
	vb.add_child(anim_name_edit)
	frames_edit = LineEdit.new()
	frames_edit.text = "0,1,2,1"
	vb.add_child(frames_edit)
	var fps_row := HBoxContainer.new()
	fps_row.add_child(UIKit.label("FPS:", 9))
	fps_spin = SpinBox.new(); fps_spin.min_value = 1; fps_spin.max_value = 60; fps_spin.value = 7
	fps_row.add_child(fps_spin)
	loop_check = CheckBox.new(); loop_check.text = "Loop"; loop_check.button_pressed = true
	fps_row.add_child(loop_check)
	flip_check = CheckBox.new(); flip_check.text = "Flip H"
	fps_row.add_child(flip_check)
	collision_check = CheckBox.new(); collision_check.text = "Collision box"
	fps_row.add_child(collision_check)
	vb.add_child(fps_row)
	vb.add_child(UIKit.button("Add / update animation", _add_animation))
	anim_list = ItemList.new()
	anim_list.custom_minimum_size = Vector2(0, 110)
	anim_list.item_selected.connect(_on_anim_selected)
	vb.add_child(anim_list)
	vb.add_child(UIKit.button("Remove selected", _remove_animation))
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.button("Save manifest JSON", _save_manifest))
	vb.add_child(UIKit.button("Load manifest JSON", _load_manifest))
	vb.add_child(UIKit.button("Export SpriteFrames .tres", _export_tres))
	vb.add_child(UIKit.button("Export atlas PNG (processed/)", _export_atlas))
	status = UIKit.label("Load a sheet to begin.", 9, UIKit.COL_DIM)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(status)

	var right := UIKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var right_vb := VBoxContainer.new()
	right.add_child(right_vb)
	right_vb.add_child(UIKit.label("Preview", 10, UIKit.COL_ACCENT))
	grid_overlay = Control.new()
	grid_overlay.custom_minimum_size = Vector2(400, 300)
	grid_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_overlay.draw.connect(_draw_overlay)
	right_vb.add_child(grid_overlay)
	preview_holder = Node2D.new()
	preview_holder.position = Vector2(200, 340)
	grid_overlay.add_child(preview_holder)
	preview_sprite = AnimatedSprite2D.new()
	preview_holder.add_child(preview_sprite)


func _load_sheet() -> void:
	var path := sheet_path_edit.text.strip_edges()
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		sheet_image = tex.get_image()
	elif FileAccess.file_exists(path):
		sheet_image = Image.load_from_file(path)
	else:
		status.text = "File not found: " + path
		return
	sheet_image.convert(Image.FORMAT_RGBA8)
	_apply_chroma()
	sheet_texture = ImageTexture.create_from_image(sheet_image)
	status.text = "Loaded %dx%d (%d cols x %d rows at current grid)" % [
		sheet_image.get_width(), sheet_image.get_height(),
		sheet_image.get_width() / int(grid_w.value), sheet_image.get_height() / int(grid_h.value)]
	grid_overlay.queue_redraw()
	_rebuild_preview()


func _apply_chroma() -> void:
	var hex := chroma_edit.text.strip_edges()
	if hex == "" or sheet_image == null:
		return
	var key := Color(hex)
	for y in range(sheet_image.get_height()):
		for x in range(sheet_image.get_width()):
			var p := sheet_image.get_pixel(x, y)
			if absf(p.r - key.r) < 0.02 and absf(p.g - key.g) < 0.02 and absf(p.b - key.b) < 0.02:
				sheet_image.set_pixel(x, y, Color(0, 0, 0, 0))


func _draw_overlay() -> void:
	if sheet_texture == null:
		return
	var scale_f := minf(1.5, 380.0 / sheet_texture.get_width())
	grid_overlay.draw_set_transform(Vector2(10, 10), 0.0, Vector2(scale_f, scale_f))
	grid_overlay.draw_texture(sheet_texture, Vector2.ZERO)
	var fw := int(grid_w.value)
	var fh := int(grid_h.value)
	var col := Color(1, 1, 0, 0.35)
	for x in range(0, sheet_texture.get_width() + 1, fw):
		grid_overlay.draw_line(Vector2(x, 0), Vector2(x, sheet_texture.get_height()), col)
	for y in range(0, sheet_texture.get_height() + 1, fh):
		grid_overlay.draw_line(Vector2(0, y), Vector2(sheet_texture.get_width(), y), col)
	# frame indices
	var cols := sheet_texture.get_width() / fw
	var rows := sheet_texture.get_height() / fh
	for r in range(rows):
		for c in range(cols):
			grid_overlay.draw_string(get_theme_default_font(), Vector2(c * fw + 2, r * fh + 10), str(r * cols + c), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.7))
	grid_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _current_manifest() -> Dictionary:
	return {
		"asset_id": sheet_path_edit.text.get_file().get_basename(),
		"sheet": sheet_path_edit.text.strip_edges(),
		"native_scale": 1,
		"display_scale": int(scale_spin.value),
		"pivot": [int(pivot_x.value), int(pivot_y.value)],
		"grid": {
			"frame_width": int(grid_w.value), "frame_height": int(grid_h.value),
			"columns": (sheet_image.get_width() / int(grid_w.value)) if sheet_image != null else 1,
			"rows": (sheet_image.get_height() / int(grid_h.value)) if sheet_image != null else 1,
		},
		"animations": animations,
	}


func _add_animation() -> void:
	var anim_name := anim_name_edit.text.strip_edges()
	if anim_name == "":
		return
	var raw := frames_edit.text.strip_edges()
	var spec := {"fps": int(fps_spin.value), "loop": loop_check.button_pressed}
	if ";" in raw or raw.count(",") >= 3 and ";" in raw + ";":
		pass
	if ";" in raw:
		var rects: Array = []
		for part in raw.split(";", false):
			var nums := part.split(",", false)
			if nums.size() == 4:
				rects.append([int(nums[0]), int(nums[1]), int(nums[2]), int(nums[3])])
		spec["rects"] = rects
	else:
		var frames: Array = []
		for part in raw.split(",", false):
			frames.append(int(part))
		spec["frames"] = frames
	animations[anim_name] = spec
	_refresh_anim_list()
	_rebuild_preview()
	status.text = "Animation '%s' saved (%d keys total)." % [anim_name, animations.size()]


func _remove_animation() -> void:
	var sel := anim_list.get_selected_items()
	if sel.is_empty():
		return
	animations.erase(anim_list.get_item_text(sel[0]).split(" ")[0])
	_refresh_anim_list()
	_rebuild_preview()


func _refresh_anim_list() -> void:
	anim_list.clear()
	for anim_name: String in animations:
		var spec: Dictionary = animations[anim_name]
		anim_list.add_item("%s  (%d frames, %d fps, %s)" % [anim_name,
			spec.get("frames", spec.get("rects", [])).size(), int(spec.get("fps", 6)),
			"loop" if bool(spec.get("loop", true)) else "once"])


func _on_anim_selected(idx: int) -> void:
	var anim_name := anim_list.get_item_text(idx).split(" ")[0]
	if preview_sprite.sprite_frames != null and preview_sprite.sprite_frames.has_animation(anim_name):
		preview_sprite.animation = anim_name
		preview_sprite.play()


func _rebuild_preview() -> void:
	if sheet_texture == null or animations.is_empty():
		return
	var grid_anims: Dictionary = {}
	var rect_anims: Dictionary = {}
	for anim_name: String in animations:
		if animations[anim_name].has("rects"):
			rect_anims[anim_name] = animations[anim_name]
		else:
			grid_anims[anim_name] = animations[anim_name]
	var frames := SpriteFramesBuilder.build(sheet_texture, {"grid": _current_manifest()["grid"], "animations": grid_anims})
	if not rect_anims.is_empty():
		var rect_frames := SpriteFramesBuilder.build_rects(sheet_texture, rect_anims)
		for anim_name in rect_frames.get_animation_names():
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, rect_frames.get_animation_speed(anim_name))
			frames.set_animation_loop(anim_name, rect_frames.get_animation_loop(anim_name))
			for i in range(rect_frames.get_frame_count(anim_name)):
				frames.add_frame(anim_name, rect_frames.get_frame_texture(anim_name, i))
	preview_sprite.sprite_frames = frames
	preview_sprite.scale = Vector2(scale_spin.value, scale_spin.value)
	preview_sprite.flip_h = flip_check.button_pressed
	preview_sprite.offset = Vector2(int(grid_w.value) / 2.0 - pivot_x.value, int(grid_h.value) / 2.0 - pivot_y.value)
	var names := frames.get_animation_names()
	if names.size() > 0:
		preview_sprite.animation = names[0]
		preview_sprite.play()
	# collision preview
	for child in preview_holder.get_children():
		if child.name == "CollisionPreview":
			child.queue_free()
	if collision_check.button_pressed:
		var box := ReferenceRect.new()
		box.name = "CollisionPreview"
		box.editor_only = false
		box.border_color = Color(0, 1, 0)
		var s := float(scale_spin.value)
		box.position = Vector2(-8 * s, -6 * s)
		box.size = Vector2(16 * s, 8 * s)
		preview_holder.add_child(box)


func _save_manifest() -> void:
	if sheet_image == null:
		status.text = "Load a sheet first."
		return
	var path := sheet_path_edit.text.strip_edges().get_basename() + ".manifest.json"
	path = path.replace("/raw/", "/manifests/")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		status.text = "Cannot write " + path
		return
	f.store_string(JSON.stringify(_current_manifest(), "  "))
	manifest_path = path
	status.text = "Manifest saved: " + path


func _load_manifest() -> void:
	var path := sheet_path_edit.text.strip_edges()
	if not path.ends_with(".json"):
		path = path.get_basename() + ".manifest.json"
		path = path.replace("/raw/", "/manifests/")
	if not FileAccess.file_exists(path):
		status.text = "No manifest at " + path
		return
	var parsed: Variant = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if not (parsed is Dictionary):
		status.text = "Bad manifest JSON."
		return
	var m: Dictionary = parsed
	sheet_path_edit.text = String(m.get("sheet", sheet_path_edit.text))
	var grid: Dictionary = m.get("grid", {})
	grid_w.value = int(grid.get("frame_width", 32))
	grid_h.value = int(grid.get("frame_height", 32))
	var pivot: Array = m.get("pivot", [16, 28])
	pivot_x.value = int(pivot[0])
	pivot_y.value = int(pivot[1])
	scale_spin.value = int(m.get("display_scale", 2))
	animations = m.get("animations", {})
	_load_sheet()
	_refresh_anim_list()
	_rebuild_preview()
	status.text = "Manifest loaded: " + path


func _export_tres() -> void:
	if preview_sprite.sprite_frames == null:
		_rebuild_preview()
	if preview_sprite.sprite_frames == null:
		status.text = "Nothing to export."
		return
	var out := sheet_path_edit.text.strip_edges().get_basename() + ".tres"
	out = out.replace("/raw/", "/processed/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var err := ResourceSaver.save(preview_sprite.sprite_frames, out)
	status.text = "SpriteFrames exported: %s" % out if err == OK else "Export failed: %d" % err


func _export_atlas() -> void:
	if sheet_image == null:
		status.text = "Load a sheet first."
		return
	var out := sheet_path_edit.text.strip_edges().replace("/raw/", "/processed/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	sheet_image.save_png(ProjectSettings.globalize_path(out))
	status.text = "Atlas exported: " + out
