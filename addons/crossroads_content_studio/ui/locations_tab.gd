@tool
extends VBoxContainer
## Location / Tileset Factory: import a tile sheet as a tileset (JSON
## metadata + copied PNG under processed/tilesets/), then paint a simple
## layered grid map — ground, decoration, collision, and gameplay markers
## (spawns, exits, item stand slots) — saved to data/locations.json.
## Runtime instantiation goes through scripts/systems/location_loader.gd.

signal data_written

const LOCATION_TYPES := ["shop", "town", "dungeon_room", "story_scene"]
const LAYERS := ["ground", "decoration", "collision", "markers"]
const MARKER_TYPES := [
	"player_spawn", "customer_spawn", "customer_exit", "shop_counter_area",
	"item_stand_slot", "door_exit", "dungeon_enemy_spawn", "dungeon_chest_spawn",
]
const MARKER_COLORS := {
	"player_spawn": Color(0.4, 1.0, 0.4),
	"customer_spawn": Color(0.4, 0.8, 1.0),
	"customer_exit": Color(0.3, 0.5, 1.0),
	"shop_counter_area": Color(1.0, 0.9, 0.4),
	"item_stand_slot": Color(1.0, 0.6, 1.0),
	"door_exit": Color(1.0, 0.5, 0.3),
	"dungeon_enemy_spawn": Color(1.0, 0.3, 0.3),
	"dungeon_chest_spawn": Color(0.9, 0.8, 0.2),
}

var scan: CCSContentScan

var palette: CCSSpriteSheetPreview
var _canvas: Control
var _loc_option: OptionButton
var _name_edit: LineEdit
var _world_option: OptionButton
var _type_option: OptionButton
var _w_spin: SpinBox
var _h_spin: SpinBox
var _layer_option: OptionButton
var _marker_option: OptionButton
var _target_edit: LineEdit
var _status: Label
var _sheet_dialog: FileDialog
var _worlds: Array[String] = []

# editing state
var loc_w: int = 20
var loc_h: int = 12
var layers := {"ground": [], "decoration": []}
var collision: Array = []
var markers: Array = []
var tileset_ref: String = ""
var tileset_meta: Dictionary = {}
var _brush_tile: int = -1
var _painting: bool = false
var _erasing: bool = false
var _current_loc_id: String = ""


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _loc_option == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_child(_mk_label("Location:"))
	_loc_option = OptionButton.new()
	_loc_option.custom_minimum_size = Vector2(140, 0)
	_loc_option.item_selected.connect(_on_location_selected)
	top.add_child(_loc_option)
	top.add_child(_mk_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(120, 0)
	top.add_child(_name_edit)
	top.add_child(_mk_label("World:"))
	_world_option = OptionButton.new()
	top.add_child(_world_option)
	top.add_child(_mk_label("Type:"))
	_type_option = OptionButton.new()
	for t in LOCATION_TYPES:
		_type_option.add_item(t)
	top.add_child(_type_option)
	_w_spin = _spin(top, "W", 4, 64, loc_w)
	_w_spin.value_changed.connect(func(v: float) -> void: _resize_map(int(v), loc_h))
	_h_spin = _spin(top, "H", 4, 64, loc_h)
	_h_spin.value_changed.connect(func(v: float) -> void: _resize_map(loc_w, int(v)))
	var save_btn := Button.new()
	save_btn.text = "Save Location"
	save_btn.pressed.connect(_on_save_location)
	top.add_child(save_btn)
	add_child(top)

	var tile_row := HBoxContainer.new()
	var sheet_btn := Button.new()
	sheet_btn.text = "Load Tile Sheet..."
	sheet_btn.pressed.connect(func() -> void: _sheet_dialog.popup_centered(Vector2i(700, 500)))
	tile_row.add_child(sheet_btn)
	var save_ts_btn := Button.new()
	save_ts_btn.text = "Save as Tileset"
	save_ts_btn.tooltip_text = "Copy the loaded sheet into processed/tilesets/ with grid metadata and use it for this map"
	save_ts_btn.pressed.connect(_on_save_tileset)
	tile_row.add_child(save_ts_btn)
	tile_row.add_child(_mk_label("Layer:"))
	_layer_option = OptionButton.new()
	for layer_name in LAYERS:
		_layer_option.add_item(layer_name)
	tile_row.add_child(_layer_option)
	tile_row.add_child(_mk_label("Marker:"))
	_marker_option = OptionButton.new()
	for m in MARKER_TYPES:
		_marker_option.add_item(m)
	tile_row.add_child(_marker_option)
	tile_row.add_child(_mk_label("Exit target:"))
	_target_edit = LineEdit.new()
	_target_edit.custom_minimum_size = Vector2(110, 0)
	_target_edit.placeholder_text = "location id"
	tile_row.add_child(_target_edit)
	add_child(tile_row)

	var split := HSplitContainer.new()
	split.split_offset = 380
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	palette = CCSSpriteSheetPreview.new()
	palette.set_grid(16, 16)
	palette.custom_minimum_size = Vector2(300, 0)
	palette.selection_changed.connect(_on_palette_selection)
	split.add_child(palette)

	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.custom_minimum_size = Vector2(360, 240)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	split.add_child(_canvas)

	_status = _mk_label("Load a tile sheet, Save as Tileset, pick a tile, then paint. Left = place, right = erase.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)

	_sheet_dialog = FileDialog.new()
	_sheet_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sheet_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sheet_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images"])
	_sheet_dialog.file_selected.connect(func(abs_path: String) -> void:
		var err := palette.load_sheet(ProjectSettings.localize_path(abs_path))
		_status.text = err if err != "" else "Sheet loaded — set the tile grid size, then Save as Tileset.")
	add_child(_sheet_dialog)

	_reset_map()


func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _spin(row: HBoxContainer, label_text: String, min_v: float, max_v: float, value: float) -> SpinBox:
	row.add_child(_mk_label(label_text))
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1
	s.value = value
	row.add_child(s)
	return s


func refresh() -> void:
	_worlds = CCSAssetPaths.known_world_ids(scan.world_order)
	_world_option.clear()
	for w in _worlds:
		_world_option.add_item(w)
	_loc_option.clear()
	_loc_option.add_item("<new>")
	for loc: Dictionary in scan.locations_raw:
		_loc_option.add_item(String(loc.get("id", "?")))
	_loc_option.select(0)


func _selected_world() -> String:
	if _world_option.selected < 0 or _worlds.is_empty():
		return "crossroads"
	return _worlds[_world_option.selected]


func _reset_map() -> void:
	layers = {"ground": [], "decoration": []}
	collision = []
	markers = []
	for i in loc_w * loc_h:
		layers["ground"].append(-1)
		layers["decoration"].append(-1)
		collision.append(0)
	if _canvas != null:
		_canvas.queue_redraw()


func _resize_map(w: int, h: int) -> void:
	var old_w := loc_w
	var old_ground: Array = layers["ground"]
	var old_deco: Array = layers["decoration"]
	var old_col := collision
	var old_h := loc_h
	loc_w = w
	loc_h = h
	_reset_map()
	for y in mini(h, old_h):
		for x in mini(w, old_w):
			layers["ground"][y * w + x] = old_ground[y * old_w + x]
			layers["decoration"][y * w + x] = old_deco[y * old_w + x]
			collision[y * w + x] = old_col[y * old_w + x]
	markers = markers.filter(func(m: Dictionary) -> bool:
		return int(m.get("x", 0)) < w and int(m.get("y", 0)) < h)
	_canvas.queue_redraw()


func _on_palette_selection() -> void:
	var sel := palette.get_selected_rects()
	if sel.is_empty() or palette.image == null:
		_brush_tile = -1
		return
	_brush_tile = palette.frame_index_at(sel[0].position)
	_status.text = "Brush tile: %d" % _brush_tile


# ---- tileset ----------------------------------------------------------------

func _on_save_tileset() -> void:
	if palette.image == null:
		_status.text = "Load a tile sheet first."
		return
	var world := _selected_world()
	var ts_id := CCSFactoryIO.sanitize_id(palette.source_path.get_file().get_basename())
	var sheet_dest := CCSAssetPaths.tileset_sheet_path(world, ts_id)
	var json_dest := CCSAssetPaths.tileset_json_path(world, ts_id)
	var err := ""
	if palette.chroma_enabled:
		err = palette.export_sheet_png(sheet_dest)
		if err == "":
			err = CCSFactoryIO.write_sidecar(sheet_dest, palette.chroma_meta().merged(
				{"original_source": palette.source_path, "tileset_id": ts_id}))
	else:
		err = CCSFactoryIO.copy_with_sidecar(palette.source_path, sheet_dest, {"tileset_id": ts_id}, true)
	if err != "":
		_status.text = "Error: %s" % err
		return
	var meta := {
		"id": ts_id,
		"sheet": sheet_dest,
		"tile_size": [palette.frame_size.x, palette.frame_size.y],
		"margin": palette.grid_margin.x,
		"spacing": palette.grid_spacing.x,
		"columns": palette.grid_columns(),
		"rows": palette.grid_rows(),
	}
	err = CCSFactoryIO.save_doc(json_dest, meta)
	if err != "":
		_status.text = "Error: %s" % err
		return
	tileset_ref = json_dest
	tileset_meta = meta
	CCSFactoryIO.rescan_filesystem()
	_status.text = "Tileset saved: %s (this map now uses it)." % json_dest
	_canvas.queue_redraw()


func _load_tileset(json_path: String) -> void:
	tileset_meta = CCSFactoryIO.load_doc(json_path)
	tileset_ref = json_path if not tileset_meta.is_empty() else ""
	if tileset_meta.is_empty():
		return
	var sheet := String(tileset_meta.get("sheet", ""))
	if FileAccess.file_exists(sheet):
		palette.load_sheet(sheet)
		var ts: Array = tileset_meta.get("tile_size", [16, 16])
		palette.set_grid(int(ts[0]), int(ts[1]), int(tileset_meta.get("margin", 0)), int(tileset_meta.get("spacing", 0)))


func _tile_src_rect(index: int) -> Rect2:
	if index < 0 or tileset_meta.is_empty():
		return Rect2()
	var ts: Array = tileset_meta.get("tile_size", [16, 16])
	var cols := maxi(1, int(tileset_meta.get("columns", 1)))
	var margin := int(tileset_meta.get("margin", 0))
	var spacing := int(tileset_meta.get("spacing", 0))
	var col := index % cols
	var row := index / cols
	return Rect2(margin + col * (int(ts[0]) + spacing), margin + row * (int(ts[1]) + spacing), int(ts[0]), int(ts[1]))


# ---- map canvas ---------------------------------------------------------------

func _cell_px() -> float:
	return clampf(minf(_canvas.size.x / loc_w, _canvas.size.y / loc_h), 6.0, 40.0)


func _draw_canvas() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.1, 0.1, 0.12))
	var cell := _cell_px()
	var font := get_theme_default_font()
	for y in loc_h:
		for x in loc_w:
			var i := y * loc_w + x
			var dest := Rect2(x * cell, y * cell, cell, cell)
			for layer_name in ["ground", "decoration"]:
				var t := int(layers[layer_name][i])
				if t >= 0 and palette.texture != null:
					_canvas.draw_texture_rect_region(palette.texture, dest, _tile_src_rect(t))
			if int(collision[i]) == 1:
				_canvas.draw_rect(dest, Color(1, 0.2, 0.2, 0.35))
			_canvas.draw_rect(dest, Color(1, 1, 1, 0.08), false, 1.0)
	for m: Dictionary in markers:
		var t := String(m.get("type", ""))
		var dest := Rect2(int(m.get("x", 0)) * cell, int(m.get("y", 0)) * cell, cell, cell)
		var col: Color = MARKER_COLORS.get(t, Color.WHITE)
		_canvas.draw_rect(dest.grow(-2.0), Color(col.r, col.g, col.b, 0.35))
		_canvas.draw_rect(dest.grow(-2.0), col, false, 1.5)
		if cell >= 14.0:
			_canvas.draw_string(font, dest.position + Vector2(2, 11), t.left(2).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
	_canvas.draw_rect(Rect2(0, 0, loc_w * cell, loc_h * cell), Color(1, 1, 1, 0.3), false, 1.0)


func _canvas_cell(pos: Vector2) -> Vector2i:
	var cell := _cell_px()
	return Vector2i(int(pos.x / cell), int(pos.y / cell))


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				_apply_cell(_canvas_cell(mb.position), false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_erasing = mb.pressed
			if mb.pressed:
				_apply_cell(_canvas_cell(mb.position), true)
	elif event is InputEventMouseMotion and (_painting or _erasing):
		_apply_cell(_canvas_cell((event as InputEventMouseMotion).position), _erasing)


func _apply_cell(c: Vector2i, erase: bool) -> void:
	if c.x < 0 or c.y < 0 or c.x >= loc_w or c.y >= loc_h:
		return
	var i := c.y * loc_w + c.x
	var layer_name := _layer_option.get_item_text(_layer_option.selected)
	match layer_name:
		"ground", "decoration":
			if erase:
				layers[layer_name][i] = -1
			elif _brush_tile >= 0:
				layers[layer_name][i] = _brush_tile
			else:
				_status.text = "Pick a brush tile from the palette first."
		"collision":
			collision[i] = 0 if erase else 1
		"markers":
			markers = markers.filter(func(m: Dictionary) -> bool:
				return int(m.get("x", -1)) != c.x or int(m.get("y", -1)) != c.y)
			if not erase:
				var m := {"type": _marker_option.get_item_text(_marker_option.selected), "x": c.x, "y": c.y}
				if String(m["type"]) == "door_exit":
					m["target"] = _target_edit.text.strip_edges()
				markers.append(m)
	_canvas.queue_redraw()


# ---- load/save ----------------------------------------------------------------

func _on_location_selected(idx: int) -> void:
	if idx <= 0:
		_current_loc_id = ""
		_name_edit.text = ""
		_reset_map()
		return
	_current_loc_id = _loc_option.get_item_text(idx)
	var loc: Dictionary = scan.locations.get(_current_loc_id, {})
	_name_edit.text = String(loc.get("name", _current_loc_id))
	var widx := _worlds.find(String(loc.get("world", "crossroads")))
	if widx >= 0:
		_world_option.select(widx)
	for i in _type_option.item_count:
		if _type_option.get_item_text(i) == String(loc.get("location_type", "shop")):
			_type_option.select(i)
			break
	loc_w = int(loc.get("width", 20))
	loc_h = int(loc.get("height", 12))
	_w_spin.set_value_no_signal(loc_w)
	_h_spin.set_value_no_signal(loc_h)
	_reset_map()
	var l: Dictionary = loc.get("layers", {})
	for layer_name in ["ground", "decoration"]:
		var arr: Array = l.get(layer_name, [])
		for i in mini(arr.size(), loc_w * loc_h):
			layers[layer_name][i] = int(arr[i])
	var col: Array = loc.get("collision", [])
	for i in mini(col.size(), loc_w * loc_h):
		collision[i] = int(col[i])
	markers = (loc.get("markers", []) as Array).duplicate(true)
	_load_tileset(String(loc.get("tileset", "")))
	_canvas.queue_redraw()
	_status.text = "Loaded location '%s'." % _current_loc_id


func _on_save_location() -> void:
	var name := _name_edit.text.strip_edges()
	if _current_loc_id == "" and name == "":
		_status.text = "Type a name for the new location."
		return
	var id := _current_loc_id
	if id == "":
		id = CCSFactoryIO.unique_id(CCSFactoryIO.sanitize_id(name), scan.locations)
	var tile_size := 16
	if not tileset_meta.is_empty():
		tile_size = int((tileset_meta.get("tile_size", [16, 16]) as Array)[0])
	var entry := {
		"id": id,
		"name": name if name != "" else id,
		"world": _selected_world(),
		"location_type": _type_option.get_item_text(_type_option.selected),
		"tileset": tileset_ref,
		"tile_size": tile_size,
		"width": loc_w,
		"height": loc_h,
		"layers": {
			"ground": (layers["ground"] as Array).duplicate(),
			"decoration": (layers["decoration"] as Array).duplicate(),
		},
		"collision": collision.duplicate(),
		"markers": markers.duplicate(true),
	}
	var err := CCSFactoryIO.upsert_entry(CCSAssetPaths.DATA_LOCATIONS, "locations", "crossroads.locations.v1", entry)
	if err != "":
		_status.text = "Error: %s" % err
		return
	_current_loc_id = id
	_status.text = "Saved location '%s' to data/locations.json." % id
	data_written.emit()
