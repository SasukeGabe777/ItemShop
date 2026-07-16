@tool
extends VBoxContainer
## Import Queue: drop any downloaded/bought files into assets/import_queue/,
## then route them from here into the right world's raw/ folder. Files are
## copied (never moved), get a sidecar recording where they came from, and
## raw/ remains the untouched permanent record.

signal data_written

var scan: CCSContentScan

var _tree: Tree
var _world_option: OptionButton
var _status: Label
var _preview_rect: TextureRect
var _worlds: Array[String] = []
var _files: Array[String] = []


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _tree == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh)
	top.add_child(refresh_btn)
	top.add_child(_mk_label("Send to world:"))
	_world_option = OptionButton.new()
	top.add_child(_world_option)
	var send_btn := Button.new()
	send_btn.text = "Copy to raw/"
	send_btn.pressed.connect(_on_send_pressed)
	top.add_child(send_btn)
	var folders_btn := Button.new()
	folders_btn.text = "Ensure Folder Structure"
	folders_btn.tooltip_text = "Create import_queue/ and every processed subfolder for the selected world"
	folders_btn.pressed.connect(_on_ensure_folders)
	top.add_child(folders_btn)
	add_child(top)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.set_column_title(0, "File")
	_tree.set_column_title(1, "Size")
	_tree.set_column_title(2, "Dimensions")
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(420, 200)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_selected)
	split.add_child(_tree)

	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(220, 200)
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	split.add_child(_preview_rect)

	_status = _mk_label("Drop files into %s and press Refresh." % CCSAssetPaths.IMPORT_QUEUE_ROOT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)


func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func refresh() -> void:
	_worlds = CCSAssetPaths.known_world_ids(scan.world_order)
	_world_option.clear()
	for w in _worlds:
		_world_option.add_item(w)
	CCSFileOps.ensure_dir(CCSAssetPaths.IMPORT_QUEUE_ROOT)
	_files = CCSFileOps.list_files_recursive(CCSAssetPaths.IMPORT_QUEUE_ROOT)
	_tree.clear()
	var root := _tree.create_item()
	for path in _files:
		if path.ends_with(".import") or path.ends_with(CCSFactoryIO.SIDE_CAR_SUFFIX):
			continue
		var row := _tree.create_item(root)
		row.set_text(0, path.trim_prefix(CCSAssetPaths.IMPORT_QUEUE_ROOT + "/"))
		var f := FileAccess.open(path, FileAccess.READ)
		row.set_text(1, "%.1f KB" % (f.get_length() / 1024.0) if f != null else "?")
		var dims := CCSFileOps.image_dimensions(path)
		row.set_text(2, "%dx%d" % [dims.x, dims.y] if dims.x > 0 else "-")
		row.set_metadata(0, path)
	if _files.is_empty():
		_status.text = "Import queue is empty — drop raw sheets into %s." % CCSAssetPaths.IMPORT_QUEUE_ROOT


func _selected_path() -> String:
	var row := _tree.get_selected()
	return String(row.get_metadata(0)) if row != null else ""


func _on_selected() -> void:
	var path := _selected_path()
	_preview_rect.texture = CCSFileOps.load_preview_texture(path)
	_status.text = path


func _on_send_pressed() -> void:
	var src := _selected_path()
	if src == "":
		_status.text = "Select a file in the queue first."
		return
	if _world_option.selected < 0:
		_status.text = "Pick a destination world."
		return
	var world := _worlds[_world_option.selected]
	var dest := "%s/%s" % [CCSAssetPaths.franchise_raw_dir(world),
		CCSFactoryIO.sanitize_filename(src.get_file().get_basename()) + "." + src.get_extension().to_lower()]
	var do_copy := func() -> void:
		var err := CCSFactoryIO.copy_with_sidecar(src, dest, {"world": world, "via": "import_queue"}, true)
		if err == "":
			CCSFactoryIO.rescan_filesystem()
			_status.text = "Copied to %s (original stays in the queue)." % dest
			data_written.emit()
		else:
			_status.text = "Error: %s" % err
	if FileAccess.file_exists(dest):
		var dialog := ConfirmationDialog.new()
		dialog.title = "Overwrite raw file?"
		dialog.dialog_text = "%s already exists and will be replaced." % dest
		add_child(dialog)
		dialog.confirmed.connect(do_copy)
		dialog.popup_centered()
	else:
		do_copy.call()


func _on_ensure_folders() -> void:
	if _world_option.selected < 0:
		return
	var world := _worlds[_world_option.selected]
	for dir in CCSAssetPaths.world_folder_set(world):
		CCSFileOps.ensure_dir(dir)
	CCSFactoryIO.rescan_filesystem()
	_status.text = "Folder structure ensured for '%s'." % world
