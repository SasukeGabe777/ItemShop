@tool
extends VBoxContainer
## Item Factory: open a raw icon/item sheet, click one tile, and turn it into
## a real game item — name + icon are the only requirements. The icon is
## sliced to processed/items/<id>.png and the entry upserted into
## data/items.json with safe defaults plus needs_ai_balance /
## needs_description markers for a later balancing/writing pass.

signal data_written

const CATEGORIES := ["misc", "weapon", "armor", "accessory", "consumable", "food", "material", "treasure", "key"]

var scan: CCSContentScan

var preview: CCSSpriteSheetPreview
var _world_option: OptionButton
var _name_edit: LineEdit
var _category_option: OptionButton
var _price_spin: SpinBox
var _create_btn: Button
var _assign_icon_btn: Button
var _update_btn: Button
var _status: Label
var _tree: Tree
var _sheet_dialog: FileDialog
var _worlds: Array[String] = []
var _rows: Array[Dictionary] = []
var _selected_item_id: String = ""


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if preview == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var sheet_btn := Button.new()
	sheet_btn.text = "Load Sheet..."
	sheet_btn.pressed.connect(func() -> void: _sheet_dialog.popup_centered(Vector2i(700, 500)))
	top.add_child(sheet_btn)
	top.add_child(_mk_label("World:"))
	_world_option = OptionButton.new()
	top.add_child(_world_option)
	top.add_child(_mk_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(150, 0)
	_name_edit.placeholder_text = "New item name"
	top.add_child(_name_edit)
	top.add_child(_mk_label("Category:"))
	_category_option = OptionButton.new()
	for c in CATEGORIES:
		_category_option.add_item(c)
	top.add_child(_category_option)
	top.add_child(_mk_label("Price:"))
	_price_spin = SpinBox.new()
	_price_spin.min_value = 0
	_price_spin.max_value = 999999
	top.add_child(_price_spin)
	add_child(top)

	var actions := HBoxContainer.new()
	_create_btn = Button.new()
	_create_btn.text = "Create Item From Selection"
	_create_btn.pressed.connect(_on_create_pressed)
	actions.add_child(_create_btn)
	_assign_icon_btn = Button.new()
	_assign_icon_btn.text = "Assign Icon to Selected Item"
	_assign_icon_btn.tooltip_text = "Replace the selected list item's icon with the selected sheet tile"
	_assign_icon_btn.pressed.connect(_on_assign_icon_pressed)
	actions.add_child(_assign_icon_btn)
	_update_btn = Button.new()
	_update_btn.text = "Update Selected Item"
	_update_btn.tooltip_text = "Write the name/category/price fields into the selected list item"
	_update_btn.pressed.connect(_on_update_pressed)
	actions.add_child(_update_btn)
	add_child(actions)

	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	preview = CCSSpriteSheetPreview.new()
	preview.set_grid(16, 16)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview)

	_tree = Tree.new()
	_tree.columns = 6
	for pair in [[0, "Icon"], [1, "ID"], [2, "Name"], [3, "World"], [4, "Category"], [5, "Price"]]:
		_tree.set_column_title(int(pair[0]), String(pair[1]))
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(0, 160)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_row_selected)
	split.add_child(_tree)

	_status = _mk_label("Load a sheet, click one tile, type a name, then Create Item From Selection.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)

	_sheet_dialog = FileDialog.new()
	_sheet_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sheet_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sheet_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images", "*.bmp ; BMP Images", "*.jpg,*.jpeg ; JPEG Images"])
	_sheet_dialog.file_selected.connect(func(abs_path: String) -> void:
		var err := preview.load_sheet(ProjectSettings.localize_path(abs_path))
		if err != "":
			_status.text = err)
	add_child(_sheet_dialog)


func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func refresh() -> void:
	_worlds = CCSAssetPaths.known_world_ids(scan.world_order)
	_world_option.clear()
	for w in _worlds:
		_world_option.add_item(w)
	_populate_tree()


func _selected_world() -> String:
	if _world_option.selected < 0 or _worlds.is_empty():
		return "crossroads"
	return _worlds[_world_option.selected]


func _populate_tree() -> void:
	_tree.clear()
	_rows.clear()
	_selected_item_id = ""
	var root := _tree.create_item()
	for it: Dictionary in scan.items_raw:
		var id := String(it.get("id", ""))
		var world := String(it.get("world", "crossroads"))
		var icon_path := CCSAssetPaths.item_processed_path(world, id)
		var has_icon := FileAccess.file_exists(icon_path)
		var row := _tree.create_item(root)
		if has_icon:
			var tex := CCSFileOps.load_preview_texture(icon_path)
			if tex != null:
				row.set_icon(0, tex)
				row.set_icon_max_width(0, 20)
		else:
			row.set_text(0, "MISSING")
			row.set_custom_color(0, Color(1.0, 0.6, 0.4))
		row.set_text(1, id)
		row.set_text(2, String(it.get("name", "")))
		row.set_text(3, world)
		row.set_text(4, String(it.get("category", "")))
		row.set_text(5, str(it.get("price", "")))
		row.set_metadata(0, _rows.size())
		_rows.append(it)


func _on_row_selected() -> void:
	var row := _tree.get_selected()
	if row == null:
		return
	var it: Dictionary = _rows[int(row.get_metadata(0))]
	_selected_item_id = String(it.get("id", ""))
	_name_edit.text = String(it.get("name", ""))
	_price_spin.value = int(it.get("price", 0))
	var cat := String(it.get("category", "misc"))
	for i in _category_option.item_count:
		if _category_option.get_item_text(i) == cat:
			_category_option.select(i)
			break
	var idx := _worlds.find(String(it.get("world", "crossroads")))
	if idx >= 0:
		_world_option.select(idx)
	_status.text = "Editing '%s' — change fields and Update, or select a tile and Assign Icon." % _selected_item_id


func _selected_icon_rect() -> Rect2i:
	var sel := preview.get_selected_rects()
	return sel[0] if not sel.is_empty() else Rect2i()


func _on_create_pressed() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "":
		_status.text = "Type a name for the new item."
		return
	var rect := _selected_icon_rect()
	if preview.image == null or rect.size == Vector2i.ZERO:
		_status.text = "Select the icon tile on the sheet first."
		return
	var world := _selected_world()
	var id := CCSFactoryIO.unique_id(CCSFactoryIO.sanitize_id(name), scan.items)
	var icon_path := CCSAssetPaths.item_processed_path(world, id)
	var err := preview.export_region_png(rect, icon_path)
	if err != "":
		_status.text = "Error: %s" % err
		return
	CCSFactoryIO.write_sidecar(icon_path, preview.chroma_meta().merged({
		"original_source": preview.source_path,
		"source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"item_id": id,
	}))
	var entry := {
		"id": id, "name": name, "world": world,
		"category": _category_option.get_item_text(_category_option.selected),
		"tags": [],
		"price": int(_price_spin.value),
		"desc": "",
		"needs_ai_balance": true,
		"needs_description": true,
	}
	err = CCSFactoryIO.upsert_entry(CCSAssetPaths.DATA_ITEMS, "items", "crossroads.items.v1", entry)
	if err != "":
		_status.text = "Error: %s" % err
		return
	CCSFactoryIO.rescan_filesystem()
	_status.text = "Created item '%s' -> %s (marked needs_ai_balance / needs_description)." % [id, icon_path]
	data_written.emit()


func _on_assign_icon_pressed() -> void:
	if _selected_item_id == "":
		_status.text = "Select an item in the list below first."
		return
	var rect := _selected_icon_rect()
	if preview.image == null or rect.size == Vector2i.ZERO:
		_status.text = "Select the icon tile on the sheet first."
		return
	var it := CCSFactoryIO.find_entry(CCSAssetPaths.DATA_ITEMS, "items", _selected_item_id)
	var world := String(it.get("world", "crossroads"))
	var icon_path := CCSAssetPaths.item_processed_path(world, _selected_item_id)
	var do_write := func() -> void:
		var err := preview.export_region_png(rect, icon_path)
		if err != "":
			_status.text = "Error: %s" % err
			return
		CCSFactoryIO.write_sidecar(icon_path, preview.chroma_meta().merged({
			"original_source": preview.source_path,
			"source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"item_id": _selected_item_id,
		}))
		CCSFactoryIO.rescan_filesystem()
		_status.text = "Icon written to %s" % icon_path
		data_written.emit()
	if FileAccess.file_exists(icon_path):
		var dialog := ConfirmationDialog.new()
		dialog.title = "Overwrite existing icon?"
		dialog.dialog_text = "%s already exists and will be replaced." % icon_path
		add_child(dialog)
		dialog.confirmed.connect(do_write)
		dialog.popup_centered()
	else:
		do_write.call()


func _on_update_pressed() -> void:
	if _selected_item_id == "":
		_status.text = "Select an item in the list below first."
		return
	var entry := CCSFactoryIO.find_entry(CCSAssetPaths.DATA_ITEMS, "items", _selected_item_id)
	if entry.is_empty():
		_status.text = "Item '%s' not found in data/items.json." % _selected_item_id
		return
	entry["name"] = _name_edit.text.strip_edges()
	entry["category"] = _category_option.get_item_text(_category_option.selected)
	entry["price"] = int(_price_spin.value)
	entry["world"] = _selected_world()
	var err := CCSFactoryIO.upsert_entry(CCSAssetPaths.DATA_ITEMS, "items", "crossroads.items.v1", entry)
	_status.text = ("Updated '%s'." % _selected_item_id) if err == "" else "Error: %s" % err
	if err == "":
		data_written.emit()
