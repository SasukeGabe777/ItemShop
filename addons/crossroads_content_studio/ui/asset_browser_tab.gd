@tool
extends VBoxContainer
## Asset Browser tab: browse raw/processed franchise assets, preview them,
## show dimensions + credit metadata, and copy a raw file into processed/.
## Never touches raw/ — copies only ever write to processed/.

const IMAGE_EXTS := ["png", "gif", "jpg", "jpeg", "webp", "bmp"]

var credits: CCSCreditsIndex
var extra_world_ids: Array[String] = []

var _franchise_option: OptionButton
var _raw_btn: Button
var _processed_btn: Button
var _file_list: ItemList
var _preview_rect: TextureRect
var _dimensions_label: Label
var _credit_text: Label
var _copy_button: Button
var _status_label: Label

var _mode: String = "raw"
var _current_files: Array[String] = []
var _selected_path: String = ""


func setup(p_credits: CCSCreditsIndex, p_extra_world_ids: Array[String]) -> void:
	credits = p_credits
	extra_world_ids = p_extra_world_ids
	if _franchise_option == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.add_child(_label("Franchise:"))
	_franchise_option = OptionButton.new()
	_franchise_option.item_selected.connect(func(_i): _populate_files())
	top.add_child(_franchise_option)
	_raw_btn = Button.new()
	_raw_btn.text = "Raw"
	_raw_btn.toggle_mode = true
	_raw_btn.button_pressed = true
	_raw_btn.pressed.connect(func(): _set_mode("raw"))
	top.add_child(_raw_btn)
	_processed_btn = Button.new()
	_processed_btn.text = "Processed"
	_processed_btn.toggle_mode = true
	_processed_btn.pressed.connect(func(): _set_mode("processed"))
	top.add_child(_processed_btn)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh)
	top.add_child(refresh_btn)
	add_child(top)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(split)

	_file_list = ItemList.new()
	_file_list.custom_minimum_size = Vector2(320, 320)
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.item_selected.connect(_on_file_selected)
	split.add_child(_file_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(280, 0)
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(256, 256)
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	right.add_child(_preview_rect)
	_dimensions_label = _label("")
	right.add_child(_dimensions_label)
	right.add_child(HSeparator.new())
	var credit_title := _label("Source / credit metadata:")
	right.add_child(credit_title)
	_credit_text = _label("")
	_credit_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_credit_text)
	right.add_child(HSeparator.new())
	_copy_button = Button.new()
	_copy_button.text = "Copy to Processed..."
	_copy_button.disabled = true
	_copy_button.pressed.connect(_on_copy_pressed)
	right.add_child(_copy_button)
	_status_label = _label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_status_label)
	split.add_child(right)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _set_mode(mode: String) -> void:
	_mode = mode
	_raw_btn.button_pressed = mode == "raw"
	_processed_btn.button_pressed = mode == "processed"
	_copy_button.disabled = mode != "raw" or _selected_path == ""
	_populate_files()


func refresh() -> void:
	_populate_franchises()
	_populate_files()


func _populate_franchises() -> void:
	var current := ""
	if _franchise_option.item_count > 0 and _franchise_option.selected >= 0:
		current = _franchise_option.get_item_text(_franchise_option.selected)
	_franchise_option.clear()
	var ids := CCSAssetPaths.known_world_ids(extra_world_ids)
	for id in ids:
		_franchise_option.add_item(id)
	if ids.is_empty():
		return
	var idx := ids.find(current)
	_franchise_option.select(maxi(idx, 0))


func _current_world() -> String:
	if _franchise_option.selected < 0:
		return ""
	return _franchise_option.get_item_text(_franchise_option.selected)


func _populate_files() -> void:
	_file_list.clear()
	_current_files.clear()
	_selected_path = ""
	_copy_button.disabled = true
	var world := _current_world()
	if world == "":
		return
	var dir := CCSAssetPaths.franchise_raw_dir(world) if _mode == "raw" else CCSAssetPaths.franchise_processed_dir(world)
	_current_files = CCSFileOps.list_files_recursive(dir, PackedStringArray(IMAGE_EXTS))
	for path in _current_files:
		_file_list.add_item(path.trim_prefix(dir + "/"))
	_clear_preview()


func _on_file_selected(index: int) -> void:
	_selected_path = _current_files[index]
	_copy_button.disabled = _mode != "raw"
	var dims := CCSFileOps.image_dimensions(_selected_path)
	if dims.x >= 0:
		_dimensions_label.text = "%d x %d px" % [dims.x, dims.y]
	else:
		_dimensions_label.text = "(dimensions unavailable)"
	var texture := CCSFileOps.load_preview_texture(_selected_path)
	_preview_rect.texture = texture
	if texture == null:
		_dimensions_label.text += "  (no in-editor preview for this format)"
	var meta := credits.lookup_for_path(_selected_path)
	_credit_text.text = _format_credit(meta) if not meta.is_empty() else "No credit/source metadata found for this file."
	_status_label.text = ""


func _clear_preview() -> void:
	_preview_rect.texture = null
	_dimensions_label.text = ""
	_credit_text.text = ""
	_status_label.text = ""


func _format_credit(meta: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["source_game", "game", "source_site", "source_page", "asset_page_url", "source_url", "contributor", "uploaded_by", "permission_notes", "size"]:
		if meta.has(key) and String(meta[key]) != "":
			lines.append("%s: %s" % [key, meta[key]])
	return "\n".join(lines) if not lines.is_empty() else "No usable credit fields found."


func _on_copy_pressed() -> void:
	if _selected_path == "":
		return
	var world := _current_world()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Copy raw asset to processed/"
	var vbox := VBoxContainer.new()
	vbox.add_child(_label("Source: %s" % _selected_path))
	var is_item_check := CheckBox.new()
	is_item_check.text = "This is an item icon (copy into processed/items/)"
	vbox.add_child(is_item_check)
	vbox.add_child(_label("Destination id (filename without extension):"))
	var id_edit := LineEdit.new()
	id_edit.text = _selected_path.get_file().get_basename()
	vbox.add_child(id_edit)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var dest_id := id_edit.text.strip_edges()
		if dest_id == "":
			_status_label.text = "Copy cancelled: destination id was empty."
			return
		var dest := CCSAssetPaths.item_processed_path(world, dest_id) if is_item_check.button_pressed else CCSAssetPaths.entity_processed_path(world, dest_id)
		var err := CCSFileOps.copy_file(_selected_path, dest)
		if err == "":
			_status_label.text = "Copied to %s" % dest
			var fs := EditorInterface.get_resource_filesystem()
			if fs != null:
				fs.scan()
		else:
			_status_label.text = "Error: %s" % err
	)
	dialog.popup_centered(Vector2i(420, 220))
