@tool
extends VBoxContainer
## Shop Furniture Factory: define/edit the movable display furniture types in
## data/shop_furniture.json (used by ShopFurnitureManager + DisplayFurniture
## at runtime). A custom sprite can be sliced straight off a loaded sheet;
## without one the piece falls back to Scenery art or a generated placeholder.

signal data_written

const FURNITURE_TYPES := ["item_stand", "counter", "shelf", "display_case", "pedestal", "small_table", "wall_rack", "vending_machine"]
const SPRITE_DIR := "res://assets/shared/furniture"

var scan: CCSContentScan

var preview: CCSSpriteSheetPreview
var _tree: Tree
var _name_edit: LineEdit
var _type_option: OptionButton
var _w_spin: SpinBox
var _h_spin: SpinBox
var _slots_spin: SpinBox
var _blocks_check: CheckBox
var _moveable_check: CheckBox
var _attention_spin: SpinBox
var _categories_edit: LineEdit
var _status: Label
var _sheet_dialog: FileDialog
var _rows: Array[Dictionary] = []
var _selected_id: String = ""
var _pending_sprite_path: String = ""


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _tree == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_child(_mk_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(140, 0)
	_name_edit.placeholder_text = "New furniture name"
	top.add_child(_name_edit)
	top.add_child(_mk_label("Type:"))
	_type_option = OptionButton.new()
	for t in FURNITURE_TYPES:
		_type_option.add_item(t)
	top.add_child(_type_option)
	_w_spin = _spin(top, "W", 16, 128, 40)
	_h_spin = _spin(top, "H", 8, 128, 24)
	_slots_spin = _spin(top, "Slots", 1, 4, 1)
	_attention_spin = _spin(top, "Attention +", 0.0, 1.0, 0.0)
	_attention_spin.step = 0.05
	add_child(top)

	var second := HBoxContainer.new()
	_blocks_check = CheckBox.new()
	_blocks_check.text = "Blocks movement"
	second.add_child(_blocks_check)
	_moveable_check = CheckBox.new()
	_moveable_check.text = "Moveable"
	_moveable_check.button_pressed = true
	second.add_child(_moveable_check)
	second.add_child(_mk_label("Allowed categories (comma, empty = all):"))
	_categories_edit = LineEdit.new()
	_categories_edit.custom_minimum_size = Vector2(180, 0)
	second.add_child(_categories_edit)
	var sheet_btn := Button.new()
	sheet_btn.text = "Load Sheet..."
	sheet_btn.pressed.connect(func() -> void: _sheet_dialog.popup_centered(Vector2i(700, 500)))
	second.add_child(sheet_btn)
	var sprite_btn := Button.new()
	sprite_btn.text = "Use Selection as Sprite"
	sprite_btn.pressed.connect(_on_use_sprite_pressed)
	second.add_child(sprite_btn)
	var save_btn := Button.new()
	save_btn.text = "Save Furniture"
	save_btn.pressed.connect(_on_save_pressed)
	second.add_child(save_btn)
	add_child(second)

	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	preview = CCSSpriteSheetPreview.new()
	preview.set_grid(16, 16)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview)

	_tree = Tree.new()
	_tree.columns = 6
	for pair in [[0, "ID"], [1, "Name"], [2, "Type"], [3, "Slots"], [4, "Moveable"], [5, "Sprite"]]:
		_tree.set_column_title(int(pair[0]), String(pair[1]))
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(0, 140)
	_tree.item_selected.connect(_on_row_selected)
	split.add_child(_tree)

	_status = _mk_label("Furniture types feed ShopFurnitureManager — the shop's movable item stands.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)

	_sheet_dialog = FileDialog.new()
	_sheet_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sheet_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sheet_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images"])
	_sheet_dialog.file_selected.connect(func(abs_path: String) -> void:
		var err := preview.load_sheet(ProjectSettings.localize_path(abs_path))
		if err != "":
			_status.text = err)
	add_child(_sheet_dialog)


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
	_tree.clear()
	_rows.clear()
	_selected_id = ""
	_pending_sprite_path = ""
	var root := _tree.create_item()
	for fu: Dictionary in scan.furniture_raw:
		var row := _tree.create_item(root)
		row.set_text(0, String(fu.get("id", "")))
		row.set_text(1, String(fu.get("name", "")))
		row.set_text(2, String(fu.get("furniture_type", "")))
		row.set_text(3, str((fu.get("display_slots", []) as Array).size()))
		row.set_text(4, "yes" if bool(fu.get("is_moveable", true)) else "no")
		var sprite := String(fu.get("sprite", ""))
		if sprite != "" and FileAccess.file_exists(sprite):
			row.set_text(5, "custom")
		elif String(fu.get("scenery", "")) != "":
			row.set_text(5, "scenery:%s" % String(fu.get("scenery", "")))
		else:
			row.set_text(5, "placeholder")
		row.set_metadata(0, _rows.size())
		_rows.append(fu)


func _on_row_selected() -> void:
	var row := _tree.get_selected()
	if row == null:
		return
	var fu: Dictionary = _rows[int(row.get_metadata(0))]
	_selected_id = String(fu.get("id", ""))
	_name_edit.text = String(fu.get("name", ""))
	for i in _type_option.item_count:
		if _type_option.get_item_text(i) == String(fu.get("furniture_type", "")):
			_type_option.select(i)
			break
	var size_arr: Array = fu.get("size", [40, 24])
	_w_spin.value = int(size_arr[0])
	_h_spin.value = int(size_arr[1])
	_slots_spin.value = maxi(1, (fu.get("display_slots", []) as Array).size())
	_blocks_check.button_pressed = bool(fu.get("blocks_movement", false))
	_moveable_check.button_pressed = bool(fu.get("is_moveable", true))
	_attention_spin.value = float(fu.get("customer_attention_modifier", 0.0))
	var cats: Array = fu.get("allowed_categories", [])
	var cat_strs: Array[String] = []
	for c in cats:
		cat_strs.append(String(c))
	_categories_edit.text = ", ".join(cat_strs)
	_pending_sprite_path = ""
	_status.text = "Editing '%s'." % _selected_id


## Evenly spread N display points across the top of the piece.
func _slot_offsets(n: int, width: float) -> Array:
	var out := []
	for i in n:
		var x := 0.0 if n == 1 else -width / 2.0 + width * (0.5 + i) / n
		out.append([int(round(x)), -12])
	return out


func _on_use_sprite_pressed() -> void:
	var sel := preview.get_selected_rects()
	if preview.image == null or sel.is_empty():
		_status.text = "Load a sheet and select the furniture sprite region first."
		return
	var base := _selected_id
	if base == "":
		base = CCSFactoryIO.sanitize_id(_name_edit.text.strip_edges())
	if base == "" or base == "unnamed":
		_status.text = "Type a name (or select an existing piece) before assigning a sprite."
		return
	var dest := "%s/%s.png" % [SPRITE_DIR, base]
	var err := preview.export_region_png(sel[0], dest)
	if err != "":
		_status.text = "Error: %s" % err
		return
	CCSFactoryIO.write_sidecar(dest, preview.chroma_meta().merged(
		{"original_source": preview.source_path, "furniture_id": base}))
	_pending_sprite_path = dest
	CCSFactoryIO.rescan_filesystem()
	_status.text = "Sprite saved to %s — now Save Furniture." % dest


func _on_save_pressed() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "" and _selected_id == "":
		_status.text = "Type a name for the new furniture piece."
		return
	var id := _selected_id
	if id == "":
		id = CCSFactoryIO.unique_id(CCSFactoryIO.sanitize_id(name), scan.furniture)
	var existing := CCSFactoryIO.find_entry(CCSAssetPaths.DATA_FURNITURE, "furniture", id)
	var width := float(_w_spin.value)
	var cats := []
	for part in _categories_edit.text.split(",", false):
		var c := part.strip_edges()
		if c != "":
			cats.append(c)
	var entry := {
		"id": id,
		"name": name if name != "" else String(existing.get("name", id)),
		"furniture_type": _type_option.get_item_text(_type_option.selected),
		"scenery": String(existing.get("scenery", "")),
		"sprite": _pending_sprite_path if _pending_sprite_path != "" else String(existing.get("sprite", "")),
		"size": [int(_w_spin.value), int(_h_spin.value)],
		"blocks_movement": _blocks_check.button_pressed,
		"display_slots": _slot_offsets(int(_slots_spin.value), width),
		"allowed_categories": cats,
		"is_moveable": _moveable_check.button_pressed,
		"customer_attention_modifier": _attention_spin.value,
		"price_modifier": float(existing.get("price_modifier", 1.0)),
		"appeal_modifiers": existing.get("appeal_modifiers", {}),
	}
	var err := CCSFactoryIO.upsert_entry(CCSAssetPaths.DATA_FURNITURE, "furniture", "crossroads.shop_furniture.v1", entry)
	if err != "":
		_status.text = "Error: %s" % err
		return
	_status.text = "Saved furniture '%s'. Reload the studio to refresh the list." % id
	data_written.emit()
