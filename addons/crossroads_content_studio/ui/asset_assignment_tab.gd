@tool
extends VBoxContainer
## Asset Assignment tab: pick a raw sprite and assign it to a hero, NPC,
## enemy, boss, or item by copying it to the naming-convention path
## ContentDatabase already expects. Existing processed art is never
## overwritten without an explicit confirmation.

const CATEGORIES := ["hero", "npc", "enemy", "boss", "item"]
const CATEGORY_LABELS := {"hero": "Heroes", "npc": "NPCs", "enemy": "Enemies", "boss": "Bosses", "item": "Items"}

var scan: CCSContentScan
var _category_option: OptionButton
var _tree: Tree
var _preview_rect: TextureRect
var _status_label: Label
var _assign_button: Button
var _category: String = "hero"
var _rows: Array[Dictionary] = []
var _selected_row: Dictionary = {}
var _file_dialog: FileDialog


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _category_option == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.add_child(_label("Category:"))
	_category_option = OptionButton.new()
	for cat in CATEGORIES:
		_category_option.add_item(CATEGORY_LABELS[cat])
	_category_option.item_selected.connect(func(i):
		_category = CATEGORIES[i]
		_populate_tree())
	top.add_child(_category_option)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh)
	top.add_child(refresh_btn)
	add_child(top)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(split)

	_tree = Tree.new()
	_tree.columns = 5
	_tree.set_column_title(0, "ID")
	_tree.set_column_title(1, "Name")
	_tree.set_column_title(2, "World")
	_tree.set_column_title(3, "Expected Path")
	_tree.set_column_title(4, "Exists")
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(560, 320)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_item_selected)
	split.add_child(_tree)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(220, 0)
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(180, 180)
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_preview_rect)
	_assign_button = Button.new()
	_assign_button.text = "Assign from Raw..."
	_assign_button.disabled = true
	_assign_button.pressed.connect(_on_assign_pressed)
	right.add_child(_assign_button)
	_status_label = _label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_status_label)
	split.add_child(right)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.gif ; GIF Images", "*.jpg,*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	_file_dialog.file_selected.connect(_on_raw_file_chosen)
	add_child(_file_dialog)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func refresh() -> void:
	_populate_tree()


func _raw_for_category() -> Array:
	match _category:
		"hero": return scan.heroes_raw
		"npc": return scan.npcs_raw
		"enemy": return scan.enemies_raw
		"boss": return scan.bosses_raw
		"item": return scan.items_raw
	return []


func _expected_path(entry: Dictionary) -> String:
	var world := String(entry.get("world", ""))
	var id := String(entry.get("id", ""))
	if _category == "item":
		return CCSAssetPaths.item_processed_path(world, id)
	return CCSAssetPaths.entity_processed_path(world, id)


func _populate_tree() -> void:
	_tree.clear()
	_rows.clear()
	_selected_row = {}
	_assign_button.disabled = true
	_preview_rect.texture = null
	_status_label.text = ""
	var root := _tree.create_item()
	for entry: Dictionary in _raw_for_category():
		var id := String(entry.get("id", ""))
		var display_name := String(entry.get("name", id))
		var world := String(entry.get("world", ""))
		var expected := _expected_path(entry)
		var exists := FileAccess.file_exists(expected)
		var item := _tree.create_item(root)
		item.set_text(0, id)
		item.set_text(1, display_name)
		item.set_text(2, world)
		item.set_text(3, expected)
		item.set_text(4, "yes" if exists else "no")
		item.set_custom_color(4, Color(0.5, 1.0, 0.5) if exists else Color(1.0, 0.6, 0.4))
		var row := {"id": id, "name": display_name, "world": world, "path": expected, "exists": exists}
		item.set_metadata(0, _rows.size())
		_rows.append(row)


func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var idx: int = item.get_metadata(0)
	_selected_row = _rows[idx]
	_assign_button.disabled = false
	var path := String(_selected_row.get("path", ""))
	_preview_rect.texture = CCSFileOps.load_preview_texture(path) if FileAccess.file_exists(path) else null
	_status_label.text = "Using generated placeholder (no processed art yet)." if not _selected_row.get("exists", false) else ""


func _on_assign_pressed() -> void:
	if _selected_row.is_empty():
		return
	var world := String(_selected_row.get("world", ""))
	var raw_dir := CCSAssetPaths.franchise_raw_dir(world)
	_file_dialog.current_dir = ProjectSettings.globalize_path(raw_dir)
	_file_dialog.popup_centered(Vector2i(640, 480))


func _on_raw_file_chosen(abs_path: String) -> void:
	if _selected_row.is_empty():
		return
	var src := ProjectSettings.localize_path(abs_path)
	var dest := String(_selected_row.get("path", ""))
	if FileAccess.file_exists(dest):
		var dialog := ConfirmationDialog.new()
		dialog.title = "Overwrite existing processed art?"
		dialog.dialog_text = "%s already exists and will be replaced." % dest
		add_child(dialog)
		dialog.confirmed.connect(func(): _do_copy(src, dest))
		dialog.popup_centered()
	else:
		_do_copy(src, dest)


func _do_copy(src: String, dest: String) -> void:
	var err := CCSFileOps.copy_file(src, dest)
	if err == "":
		_status_label.text = "Assigned %s -> %s" % [src, dest]
		var fs := EditorInterface.get_resource_filesystem()
		if fs != null:
			fs.scan()
		_populate_tree()
	else:
		_status_label.text = "Error: %s" % err
