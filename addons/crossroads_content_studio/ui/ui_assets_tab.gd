@tool
extends VBoxContainer
## UI Assets tab: previews shared UI art (icon, backgrounds, buttons, panels,
## cursors) and can create the standard assets/shared/ui/ subfolders. Never
## touches game_theme.tres or any scene — this tab only looks at images.

const IMAGE_EXTS := ["png", "gif", "jpg", "jpeg", "webp", "bmp"]

# key -> {label, dir, note}. "panels" also covers menu frames and selection
# bars — the spec's folder list has one panels/ bucket for all of those.
var _slots := [
	{"label": "App Icon", "dir": CCSAssetPaths.UI_ROOT, "match": ["icon.png"]},
	{"label": "Title / Backgrounds", "dir": "%s/backgrounds" % CCSAssetPaths.UI_ROOT, "also_root_match": ["titlescreen", "background", "title"]},
	{"label": "Buttons", "dir": "%s/buttons" % CCSAssetPaths.UI_ROOT},
	{"label": "Panels / Frames / Selection Bars", "dir": "%s/panels" % CCSAssetPaths.UI_ROOT},
	{"label": "Cursors", "dir": "%s/cursors" % CCSAssetPaths.UI_ROOT},
	{"label": "Icons (misc)", "dir": "%s/icons" % CCSAssetPaths.UI_ROOT},
	{"label": "Fonts", "dir": "%s/fonts" % CCSAssetPaths.UI_ROOT, "images_only": false},
]

var _sections_container: VBoxContainer


func setup() -> void:
	if _sections_container == null:
		_build_ui()
	refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Crossroads Content Studio — UI Assets"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var note := Label.new()
	note.text = "Title screens, menus, and buttons should stay real Godot UI nodes (Label, Button, Theme). Do not bake title/menu text into image files — art here is background/frame/icon art only."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(note)

	var top := HBoxContainer.new()
	var ensure_btn := Button.new()
	ensure_btn.text = "Ensure Folder Structure"
	ensure_btn.pressed.connect(_on_ensure_folders)
	top.add_child(ensure_btn)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh)
	top.add_child(refresh_btn)
	add_child(top)
	add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_sections_container = VBoxContainer.new()
	_sections_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sections_container)

	_ensure_folders_silent()
	refresh()


## No filesystem rescan here: this runs during the dock's own startup, and
## triggering a scan while the editor is still finishing plugin init causes a
## harmless-but-noisy internal engine warning. The button below is safe
## because by the time a user can click it, the editor has settled.
func _ensure_folders_silent() -> void:
	for sub in CCSAssetPaths.UI_SUBFOLDERS:
		CCSFileOps.ensure_dir("%s/%s" % [CCSAssetPaths.UI_ROOT, sub])


func _on_ensure_folders() -> void:
	_ensure_folders_silent()
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null:
		fs.scan()
	refresh()


func refresh() -> void:
	for child in _sections_container.get_children():
		child.queue_free()
	for slot in _slots:
		_sections_container.add_child(_build_section(slot))


func _build_section(slot: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var header := Label.new()
	header.text = "%s  (%s)" % [String(slot.label), String(slot.dir)]
	header.add_theme_font_size_override("font_size", 14)
	box.add_child(header)

	var files: Array[String] = []
	if slot.has("match"):
		for name in slot["match"]:
			var p := "%s/%s" % [slot.dir, name]
			if FileAccess.file_exists(p):
				files.append(p)
	else:
		files = CCSFileOps.list_files_recursive(slot.dir, PackedStringArray(IMAGE_EXTS) if slot.get("images_only", true) else PackedStringArray())
		if slot.has("also_root_match"):
			for path in CCSFileOps.list_files_recursive(CCSAssetPaths.UI_ROOT, PackedStringArray(IMAGE_EXTS)):
				var stem := path.get_file().get_basename().to_lower()
				for token in slot["also_root_match"]:
					if stem.find(String(token)) != -1:
						files.append(path)
						break

	if files.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(none yet — drop files into %s)" % String(slot.dir)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		box.add_child(empty_label)
	else:
		var flow := HFlowContainer.new()
		for path in files:
			flow.add_child(_thumb(path))
		box.add_child(flow)
	box.add_child(HSeparator.new())
	return box


func _thumb(path: String) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(96, 96)
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(80, 80)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = CCSFileOps.load_preview_texture(path)
	cell.add_child(rect)
	var label := Label.new()
	label.text = path.get_file()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return cell
