@tool
class_name CCSEntityFactoryTab
extends VBoxContainer
## Shared base for the Hero / Customer / Enemy factory tabs. Subclasses
## override the _cfg_* hooks to say which data file they edit, which standard
## animations apply, and which stat fields to show. Everything else — entity
## list, sheet loading, animation assignment, manifest + sheet + data-entry
## saving, static-sprite fallback — lives here once.

signal data_written

var scan: CCSContentScan

var anim_editor: CCSAnimationSetEditor
var _entity_option: OptionButton
var _name_edit: LineEdit
var _world_option: OptionButton
var _status: Label
var _fields_box: HFlowContainer
var _sheet_dialog: FileDialog
var _current_id: String = ""
var _worlds: Array[String] = []


# ---- subclass hooks --------------------------------------------------------

func _cfg_type_label() -> String:
	return "Entity"


func _cfg_data_path() -> String:
	return ""


func _cfg_array_key() -> String:
	return ""


func _cfg_schema_tag() -> String:
	return ""


func _cfg_required_anims() -> Array[String]:
	return []


func _cfg_optional_anims() -> Array[String]:
	return []


## Existing entries for the picker, from the scan.
func _cfg_entries() -> Array:
	return []


func _cfg_default_entry(id: String, name: String, world: String) -> Dictionary:
	return {"id": id, "name": name, "world": world}


## Subclasses add their stat controls into `box` here.
func _build_extra_fields(_box: HFlowContainer) -> void:
	pass


## Subclasses copy control values into the entry before it is saved.
func _apply_extra_fields(_entry: Dictionary) -> void:
	pass


## Subclasses push entry values into their controls when one is selected.
func _load_extra_fields(_entry: Dictionary) -> void:
	pass


# ---- shared implementation -------------------------------------------------

func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _entity_option == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_child(_mk_label("%s:" % _cfg_type_label()))
	_entity_option = OptionButton.new()
	_entity_option.custom_minimum_size = Vector2(170, 0)
	_entity_option.item_selected.connect(_on_entity_selected)
	top.add_child(_entity_option)
	top.add_child(_mk_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(140, 0)
	_name_edit.placeholder_text = "New %s name" % _cfg_type_label().to_lower()
	top.add_child(_name_edit)
	top.add_child(_mk_label("World:"))
	_world_option = OptionButton.new()
	top.add_child(_world_option)
	var sheet_btn := Button.new()
	sheet_btn.text = "Load Sheet..."
	sheet_btn.pressed.connect(func() -> void: _sheet_dialog.popup_centered(Vector2i(700, 500)))
	top.add_child(sheet_btn)
	var save_btn := Button.new()
	save_btn.text = "Save %s" % _cfg_type_label()
	save_btn.pressed.connect(_on_save_pressed)
	top.add_child(save_btn)
	var static_btn := Button.new()
	static_btn.text = "Save Static Sprite Only"
	static_btn.tooltip_text = "Export the first selected frame as processed/<id>.png (no animations)"
	static_btn.pressed.connect(_on_save_static_pressed)
	top.add_child(static_btn)
	add_child(top)

	_fields_box = HFlowContainer.new()
	_build_extra_fields(_fields_box)
	add_child(_fields_box)

	anim_editor = CCSAnimationSetEditor.new()
	anim_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(anim_editor)
	anim_editor.set_animation_names(_cfg_required_anims(), _cfg_optional_anims())

	_status = _mk_label("Pick an existing %s or type a name for a new one, then load a raw sheet." % _cfg_type_label().to_lower())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)

	_sheet_dialog = FileDialog.new()
	_sheet_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sheet_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sheet_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images", "*.bmp ; BMP Images", "*.jpg,*.jpeg ; JPEG Images"])
	_sheet_dialog.file_selected.connect(_on_sheet_chosen)
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
	_entity_option.clear()
	_entity_option.add_item("<new>")
	var keep_idx := 0
	for entry: Dictionary in _cfg_entries():
		_entity_option.add_item(String(entry.get("id", "?")))
		if String(entry.get("id", "")) == _current_id:
			keep_idx = _entity_option.item_count - 1
	_entity_option.select(keep_idx)
	if keep_idx == 0:
		_current_id = ""


func selected_world() -> String:
	if _world_option.selected < 0 or _worlds.is_empty():
		return "crossroads"
	return _worlds[_world_option.selected]


func _select_world(world: String) -> void:
	var idx := _worlds.find(world)
	if idx >= 0:
		_world_option.select(idx)


func _entry_by_id(id: String) -> Dictionary:
	for entry: Dictionary in _cfg_entries():
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func _on_entity_selected(idx: int) -> void:
	anim_editor.clear_animations()
	if idx <= 0:
		_current_id = ""
		_name_edit.text = ""
		return
	_current_id = _entity_option.get_item_text(idx)
	var entry := _entry_by_id(_current_id)
	_name_edit.text = String(entry.get("name", _current_id))
	_select_world(String(entry.get("world", "crossroads")))
	_load_extra_fields(entry)
	# pull the existing manifest + sheet back into the editor if there is one
	var world := String(entry.get("world", "crossroads"))
	var mpath := CCSAssetPaths.manifest_path(world, _current_id)
	if FileAccess.file_exists(mpath):
		var manifest := CCSFactoryIO.load_doc(mpath)
		var sheet := String(manifest.get("sheet", ""))
		if sheet != "" and FileAccess.file_exists(sheet):
			anim_editor.load_sheet(sheet)
		anim_editor.load_manifest(manifest)
		_status.text = "Loaded existing manifest %s" % mpath
	else:
		_status.text = "No manifest yet for '%s' — load a sheet and assign animations." % _current_id


func _on_sheet_chosen(abs_path: String) -> void:
	var res := ProjectSettings.localize_path(abs_path)
	var err := anim_editor.load_sheet(res)
	_status.text = err if err != "" else "Sheet loaded: %s" % res


func _resolve_save_id() -> String:
	if _current_id != "":
		return _current_id
	var name := _name_edit.text.strip_edges()
	if name == "":
		return ""
	var taken := {}
	for entry: Dictionary in _cfg_entries():
		taken[String(entry.get("id", ""))] = true
	return CCSFactoryIO.unique_id(CCSFactoryIO.sanitize_id(name), taken)


func _on_save_pressed() -> void:
	var id := _resolve_save_id()
	if id == "":
		_status.text = "Give the new %s a name first." % _cfg_type_label().to_lower()
		return
	if anim_editor.sheet_path == "":
		_status.text = "Load a sprite sheet first (or use Save Static Sprite Only)."
		return
	var missing := anim_editor.missing_required()
	if not missing.is_empty():
		_status.text = "Missing required animations: %s" % ", ".join(missing)
		return
	var world := selected_world()

	# 1. write the sheet into processed/sheets/ (raw stays untouched); with
	# background removal on, the processed copy is the keyed version so the
	# manifest animations render without the sheet's canvas color
	var sheet_dest := CCSAssetPaths.sheet_processed_path(world, id)
	var err := ""
	if anim_editor.preview.chroma_enabled:
		err = anim_editor.preview.export_sheet_png(sheet_dest)
		if err == "":
			err = CCSFactoryIO.write_sidecar(sheet_dest, anim_editor.preview.chroma_meta().merged(
				{"original_source": anim_editor.sheet_path, "entity_id": id, "world": world}))
	else:
		err = CCSFactoryIO.copy_with_sidecar(anim_editor.sheet_path, sheet_dest,
			{"entity_id": id, "world": world}, true)
	if err != "":
		_status.text = "Error: %s" % err
		return

	# 2. write the runtime manifest
	var manifest := anim_editor.build_manifest(id, sheet_dest)
	err = CCSFactoryIO.save_manifest(world, id, manifest)
	if err != "":
		_status.text = "Error: %s" % err
		return

	# 3. upsert the data entry (existing entries keep fields we don't edit)
	var entry := _entry_by_id(id)
	if entry.is_empty():
		entry = _cfg_default_entry(id, _name_edit.text.strip_edges(), world)
	else:
		entry = entry.duplicate(true)
		entry["name"] = _name_edit.text.strip_edges()
		entry["world"] = world
	_apply_extra_fields(entry)
	err = CCSFactoryIO.upsert_entry(_cfg_data_path(), _cfg_array_key(), _cfg_schema_tag(), entry)
	if err != "":
		_status.text = "Error: %s" % err
		return

	CCSFactoryIO.rescan_filesystem()
	_current_id = id
	_status.text = "Saved %s '%s' (sheet, manifest, data entry)." % [_cfg_type_label().to_lower(), id]
	saved_entity(id)
	data_written.emit()


## Fallback path: a single static frame at processed/<id>.png, still creating
## the data entry — good enough for background customers.
func _on_save_static_pressed() -> void:
	var id := _resolve_save_id()
	if id == "":
		_status.text = "Give the new %s a name first." % _cfg_type_label().to_lower()
		return
	var sel := anim_editor.preview.get_selected_rects()
	if anim_editor.preview.image == null or sel.is_empty():
		_status.text = "Load a sheet and select one frame first."
		return
	var world := selected_world()
	var dest := CCSAssetPaths.entity_processed_path(world, id)
	var err := anim_editor.preview.export_region_png(sel[0], dest)
	if err != "":
		_status.text = "Error: %s" % err
		return
	CCSFactoryIO.write_sidecar(dest, anim_editor.preview.chroma_meta().merged(
		{"original_source": anim_editor.sheet_path, "entity_id": id, "world": world}))
	var entry := _entry_by_id(id)
	if entry.is_empty():
		entry = _cfg_default_entry(id, _name_edit.text.strip_edges(), world)
	else:
		entry = entry.duplicate(true)
	_apply_extra_fields(entry)
	err = CCSFactoryIO.upsert_entry(_cfg_data_path(), _cfg_array_key(), _cfg_schema_tag(), entry)
	if err != "":
		_status.text = "Error: %s" % err
		return
	CCSFactoryIO.rescan_filesystem()
	_current_id = id
	_status.text = "Saved static sprite %s and data entry '%s'." % [dest, id]
	saved_entity(id)
	data_written.emit()


## Hook for subclasses that need to react after a save (e.g. duplicate flow).
func saved_entity(_id: String) -> void:
	pass


# small helpers subclasses use to build stat fields

func add_spin(box: Container, label_text: String, min_v: float, max_v: float, value: float, step: float = 1.0) -> SpinBox:
	var wrap := HBoxContainer.new()
	wrap.add_child(_mk_label(label_text))
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	wrap.add_child(s)
	box.add_child(wrap)
	return s


func add_option(box: Container, label_text: String, values: Array) -> OptionButton:
	var wrap := HBoxContainer.new()
	wrap.add_child(_mk_label(label_text))
	var o := OptionButton.new()
	for v in values:
		o.add_item(String(v))
	wrap.add_child(o)
	box.add_child(wrap)
	return o


func option_value(o: OptionButton) -> String:
	return o.get_item_text(o.selected) if o.selected >= 0 else ""


func select_option(o: OptionButton, value: String) -> void:
	for i in o.item_count:
		if o.get_item_text(i) == value:
			o.select(i)
			return
