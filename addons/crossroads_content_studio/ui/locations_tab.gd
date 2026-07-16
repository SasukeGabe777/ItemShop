@tool
extends VBoxContainer
## Location / Tileset Factory: import a tile sheet as a tileset (JSON
## metadata + copied PNG under processed/tilesets/), then paint a simple
## layered grid map — ground, decoration, collision, and gameplay markers
## (spawns, exits, item stand slots) — saved to data/locations.json.
## Runtime instantiation goes through scripts/systems/location_loader.gd.

signal data_written

const LOCATION_TYPES := ["shop", "town", "dungeon_room", "story_scene"]
const LAYERS := ["ground", "walls", "decoration", "collision", "markers"]
const MARKER_TYPES := [
	"player_spawn", "customer_spawn", "customer_exit", "dungeon_enemy_spawn",
	"dungeon_chest_spawn", "item_stand_slot", "door_exit", "dialogue_trigger", "boss_trigger",
	"shop_counter_area",
]
const MARKER_LABELS := {
	"player_spawn": "Player Spawn", "customer_spawn": "Customer Spawn", "customer_exit": "Customer Exit",
	"dungeon_enemy_spawn": "Enemy Spawn", "dungeon_chest_spawn": "Chest", "item_stand_slot": "Item Stand",
	"door_exit": "Exit / Door", "dialogue_trigger": "Dialogue Trigger", "boss_trigger": "Boss Trigger",
	"shop_counter_area": "Shop Counter Area",
}
const MARKER_COLORS := {
	"player_spawn": Color(0.4, 1.0, 0.4),
	"customer_spawn": Color(0.4, 0.8, 1.0),
	"customer_exit": Color(0.3, 0.5, 1.0),
	"item_stand_slot": Color(1.0, 0.6, 1.0),
	"door_exit": Color(1.0, 0.5, 0.3),
	"dungeon_enemy_spawn": Color(1.0, 0.3, 0.3),
	"dungeon_chest_spawn": Color(0.9, 0.8, 0.2),
	"dialogue_trigger": Color(0.4, 1.0, 0.9),
	"boss_trigger": Color(0.9, 0.2, 0.7),
	"shop_counter_area": Color(1.0, 0.9, 0.4),
}

const WORKSHOP_BRIDGE := preload("res://scripts/dev/location_workshop_bridge.gd")

var scan: CCSContentScan

var palette: CCSSpriteSheetPreview
var _canvas: Control
var _loc_option: OptionButton
var _name_edit: LineEdit
var _id_edit: LineEdit
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
var _tileset_option: OptionButton
var _tileset_paths: Array[String] = []
var _map_zoom_label: Label

# editing state
var loc_w: int = 20
var loc_h: int = 12
var layers := {"ground": [], "walls": [], "decoration": []}
var collision: Array = []
var markers: Array = []
var tileset_ref: String = ""
var tileset_meta: Dictionary = {}
var _brush_tile: int = -1
var _painting: bool = false
var _erasing: bool = false
var _current_loc_id: String = ""
var _drag_marker_index: int = -1
var _map_zoom: int = 2
var locations_data_path: String = CCSAssetPaths.DATA_LOCATIONS


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
	top.add_child(_mk_label("ID:"))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size = Vector2(120, 0)
	_id_edit.placeholder_text = "stable_location_id"
	top.add_child(_id_edit)
	top.add_child(_mk_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(120, 0)
	top.add_child(_name_edit)
	top.add_child(_mk_label("World:"))
	_world_option = OptionButton.new()
	_world_option.item_selected.connect(func(_idx: int) -> void: _refresh_tileset_options())
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
	var play_btn := Button.new()
	play_btn.text = "PLAY THIS LOCATION"
	play_btn.tooltip_text = "Save and launch this location in isolated development state"
	play_btn.pressed.connect(play_this_location)
	top.add_child(play_btn)
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
	tile_row.add_child(_mk_label("Existing tileset:"))
	_tileset_option = OptionButton.new()
	_tileset_option.custom_minimum_size.x = 170
	tile_row.add_child(_tileset_option)
	var use_ts_btn := Button.new()
	use_ts_btn.text = "Use"
	use_ts_btn.pressed.connect(_use_selected_tileset)
	tile_row.add_child(use_ts_btn)
	tile_row.add_child(_mk_label("Layer:"))
	_layer_option = OptionButton.new()
	for layer_name in LAYERS:
		_layer_option.add_item(layer_name)
	tile_row.add_child(_layer_option)
	tile_row.add_child(_mk_label("Marker:"))
	_marker_option = OptionButton.new()
	for m in MARKER_TYPES:
		_marker_option.add_item(String(MARKER_LABELS.get(m, m)))
		_marker_option.set_item_metadata(_marker_option.item_count - 1, m)
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

	var map_box := VBoxContainer.new()
	map_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_bar := HBoxContainer.new()
	map_bar.add_child(_mk_label("Map zoom:"))
	var zoom_out := Button.new()
	zoom_out.text = "-"
	zoom_out.pressed.connect(func() -> void: _set_map_zoom(_map_zoom - 1))
	map_bar.add_child(zoom_out)
	_map_zoom_label = _mk_label("2x")
	map_bar.add_child(_map_zoom_label)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.pressed.connect(func() -> void: _set_map_zoom(_map_zoom + 1))
	map_bar.add_child(zoom_in)
	map_bar.add_child(_mk_label("Nearest-neighbor preview; drag an existing marker to move it."))
	map_box.add_child(map_bar)
	var map_scroll := ScrollContainer.new()
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_box.add_child(map_scroll)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	map_scroll.add_child(_canvas)
	split.add_child(map_box)

	_status = _mk_label("Choose or load a tileset, pick a layer and tile, then paint. Left = place/drag marker, right = erase.")
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
	_update_canvas_size()


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
	var previous_id := _current_loc_id
	_worlds = CCSAssetPaths.known_world_ids(scan.world_order)
	_world_option.clear()
	for w in _worlds:
		_world_option.add_item(w)
	_loc_option.clear()
	_loc_option.add_item("<new>")
	for loc: Dictionary in scan.locations_raw:
		_loc_option.add_item(String(loc.get("id", "?")))
	var selected_idx := 0
	for i in range(1, _loc_option.item_count):
		if _loc_option.get_item_text(i) == previous_id:
			selected_idx = i
			break
	_loc_option.select(selected_idx)
	_refresh_tileset_options()


func _selected_world() -> String:
	if _world_option.selected < 0 or _worlds.is_empty():
		return "crossroads"
	return _worlds[_world_option.selected]


func _refresh_tileset_options() -> void:
	if _tileset_option == null:
		return
	_tileset_paths.clear()
	_tileset_option.clear()
	var dir := DirAccess.open(CCSAssetPaths.tileset_dir(_selected_world()))
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".json") and not file.ends_with(".meta.json"):
				_tileset_paths.append(CCSAssetPaths.tileset_dir(_selected_world()).path_join(file))
	_tileset_paths.sort()
	if _tileset_paths.is_empty():
		_tileset_option.add_item("<none saved>")
		_tileset_option.disabled = true
		return
	_tileset_option.disabled = false
	for path in _tileset_paths:
		_tileset_option.add_item(path.get_file().get_basename())
	var current := _tileset_paths.find(tileset_ref)
	if current >= 0:
		_tileset_option.select(current)


func _use_selected_tileset() -> void:
	if _tileset_paths.is_empty() or _tileset_option.selected < 0:
		_status.text = "This world has no saved tileset yet. Load a tile sheet and Save as Tileset."
		return
	_load_tileset(_tileset_paths[_tileset_option.selected])
	_status.text = "Using tileset %s" % tileset_ref
	_canvas.queue_redraw()


func _set_map_zoom(value: int) -> void:
	_map_zoom = clampi(value, 1, 4)
	if _map_zoom_label != null:
		_map_zoom_label.text = "%dx" % _map_zoom
	_update_canvas_size()


func _update_canvas_size() -> void:
	if _canvas == null:
		return
	var cell := _cell_px()
	_canvas.custom_minimum_size = Vector2(loc_w * cell, loc_h * cell)
	_canvas.queue_redraw()


func _reset_map() -> void:
	layers = {"ground": [], "walls": [], "decoration": []}
	collision = []
	markers = []
	for i in loc_w * loc_h:
		layers["ground"].append(-1)
		layers["walls"].append(-1)
		layers["decoration"].append(-1)
		collision.append(0)
	if _canvas != null:
		_update_canvas_size()
		_canvas.queue_redraw()


func _resize_map(w: int, h: int) -> void:
	var old_w := loc_w
	var old_ground: Array = layers["ground"]
	var old_walls: Array = layers["walls"]
	var old_deco: Array = layers["decoration"]
	var old_col := collision
	var old_h := loc_h
	loc_w = w
	loc_h = h
	_reset_map()
	for y in mini(h, old_h):
		for x in mini(w, old_w):
			layers["ground"][y * w + x] = old_ground[y * old_w + x]
			layers["walls"][y * w + x] = old_walls[y * old_w + x]
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
	_refresh_tileset_options()
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
	return 16.0 * _map_zoom


func _draw_canvas() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.1, 0.1, 0.12))
	var cell := _cell_px()
	var font := get_theme_default_font()
	for y in loc_h:
		for x in loc_w:
			var i := y * loc_w + x
			var dest := Rect2(x * cell, y * cell, cell, cell)
			for layer_name in ["ground", "walls", "decoration"]:
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
	if _selected_layer() == "markers":
		_on_marker_canvas_input(event)
		return
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


func _selected_layer() -> String:
	return _layer_option.get_item_text(_layer_option.selected) if _layer_option != null and _layer_option.selected >= 0 else "ground"


func _on_marker_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var cell := _canvas_cell(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_marker_index = _marker_at(cell)
				if _drag_marker_index < 0:
					_apply_cell(cell, false)
			else:
				_drag_marker_index = -1
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_apply_cell(cell, true)
	elif event is InputEventMouseMotion and _drag_marker_index >= 0:
		var cell := _canvas_cell((event as InputEventMouseMotion).position)
		if cell.x >= 0 and cell.y >= 0 and cell.x < loc_w and cell.y < loc_h:
			markers[_drag_marker_index]["x"] = cell.x
			markers[_drag_marker_index]["y"] = cell.y
			_canvas.queue_redraw()


func _marker_at(cell: Vector2i) -> int:
	for i in range(markers.size() - 1, -1, -1):
		if int((markers[i] as Dictionary).get("x", -1)) == cell.x and int((markers[i] as Dictionary).get("y", -1)) == cell.y:
			return i
	return -1


func move_marker_at(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var index := _marker_at(from_cell)
	if index < 0 or to_cell.x < 0 or to_cell.y < 0 or to_cell.x >= loc_w or to_cell.y >= loc_h:
		return false
	markers[index]["x"] = to_cell.x
	markers[index]["y"] = to_cell.y
	_canvas.queue_redraw()
	return true


func _apply_cell(c: Vector2i, erase: bool) -> void:
	if c.x < 0 or c.y < 0 or c.x >= loc_w or c.y >= loc_h:
		return
	var i := c.y * loc_w + c.x
	var layer_name := _selected_layer()
	match layer_name:
		"ground", "walls", "decoration":
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
				var marker_type := String(_marker_option.get_item_metadata(_marker_option.selected))
				var m := {"type": marker_type, "x": c.x, "y": c.y}
				if String(m["type"]) == "door_exit":
					m["target"] = _target_edit.text.strip_edges()
				markers.append(m)
	_canvas.queue_redraw()


func paint_cell(layer_name: String, cell: Vector2i, tile_index: int = 0, erase: bool = false) -> bool:
	for i in _layer_option.item_count:
		if _layer_option.get_item_text(i) == layer_name:
			_layer_option.select(i)
			_brush_tile = tile_index
			_apply_cell(cell, erase)
			return true
	return false


func place_marker(marker_type: String, cell: Vector2i, target: String = "") -> bool:
	for i in _marker_option.item_count:
		if String(_marker_option.get_item_metadata(i)) == marker_type:
			_marker_option.select(i)
			_target_edit.text = target
			paint_cell("markers", cell)
			return true
	return false


# ---- load/save ----------------------------------------------------------------

func _on_location_selected(idx: int) -> void:
	if idx <= 0:
		_current_loc_id = ""
		_id_edit.text = ""
		_name_edit.text = ""
		_reset_map()
		return
	_current_loc_id = _loc_option.get_item_text(idx)
	var loc: Dictionary = scan.locations.get(_current_loc_id, {})
	load_location_data(loc)


func load_location_data(loc: Dictionary) -> void:
	if loc.is_empty():
		return
	_current_loc_id = String(loc.get("id", ""))
	_id_edit.text = _current_loc_id
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
	for layer_name in ["ground", "walls", "decoration"]:
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


func prepare_from_brief(brief: Dictionary) -> void:
	var id := CCSFactoryIO.sanitize_id(String(brief.get("id", brief.get("location_name", ""))))
	_current_loc_id = id
	_id_edit.text = id
	_name_edit.text = String(brief.get("location_name", id))
	var world_idx := _worlds.find(String(brief.get("world", "crossroads")))
	if world_idx >= 0:
		_world_option.select(world_idx)
	_refresh_tileset_options()
	for i in _type_option.item_count:
		if _type_option.get_item_text(i) == String(brief.get("location_type", "town")):
			_type_option.select(i)
	var dimensions: Dictionary = brief.get("dimensions", {})
	_resize_map(int(dimensions.get("width", loc_w)), int(dimensions.get("height", loc_h)))
	_w_spin.set_value_no_signal(loc_w)
	_h_spin.set_value_no_signal(loc_h)
	_status.text = "Brief applied to map '%s'. Paint or load its saved layout." % id


func _on_save_location() -> void:
	save_location()


func save_location() -> bool:
	var name := _name_edit.text.strip_edges()
	var raw_id := _id_edit.text.strip_edges()
	if name == "" or raw_id == "":
		_status.text = "Location name and stable ID are required."
		return false
	var id := CCSFactoryIO.sanitize_id(raw_id)
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
			"walls": (layers["walls"] as Array).duplicate(),
			"decoration": (layers["decoration"] as Array).duplicate(),
		},
		"collision": collision.duplicate(),
		"markers": markers.duplicate(true),
	}
	var err := CCSFactoryIO.upsert_entry(locations_data_path, "locations", "crossroads.locations.v1", entry)
	if err != "":
		_status.text = "Error: %s" % err
		return false
	_current_loc_id = id
	_id_edit.text = id
	_status.text = "Saved location '%s' to data/locations.json." % id
	data_written.emit()
	return true


func current_location_entry() -> Dictionary:
	var doc := CCSFactoryIO.load_doc(locations_data_path)
	for row: Dictionary in doc.get("locations", []):
		if String(row.get("id", "")) == _current_loc_id:
			return row
	return {}


func play_this_location(start_editor: bool = true) -> bool:
	if not save_location():
		return false
	if not WORKSHOP_BRIDGE.prepare_launch(_current_loc_id):
		_status.text = "Could not prepare the development launch request."
		return false
	_status.text = "Launching '%s' in isolated development state..." % _current_loc_id
	if start_editor and Engine.is_editor_hint():
		EditorInterface.play_custom_scene("res://scenes/dev/dev_location.tscn")
	return true
