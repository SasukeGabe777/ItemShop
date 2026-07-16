@tool
class_name CCSFileOps
extends RefCounted
## Filesystem helpers for the content studio: directory creation, safe
## copying, recursive listing, and cheap image-dimension reads (header-only,
## so browsing hundreds of raw sheets stays fast).

static func ensure_dir(res_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(res_path))


static func file_exists(res_path: String) -> bool:
	return FileAccess.file_exists(res_path)


## Copies src to dest, creating parent directories as needed. Never touches
## the source file. Returns "" on success or an error message.
static func copy_file(src_res_path: String, dest_res_path: String) -> String:
	if not FileAccess.file_exists(src_res_path):
		return "source file does not exist: %s" % src_res_path
	ensure_dir(dest_res_path.get_base_dir())
	var err := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(src_res_path),
		ProjectSettings.globalize_path(dest_res_path)
	)
	if err != OK:
		return "copy failed (%s): %s -> %s" % [error_string(err), src_res_path, dest_res_path]
	return ""


static func list_files_recursive(res_dir: String, extensions: PackedStringArray = []) -> Array[String]:
	var out: Array[String] = []
	_walk(res_dir, extensions, out)
	out.sort()
	return out


static func _walk(res_dir: String, extensions: PackedStringArray, out: Array[String]) -> void:
	var dir := DirAccess.open(res_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := "%s/%s" % [res_dir, name]
		if dir.current_is_dir():
			_walk(full, extensions, out)
		else:
			if extensions.is_empty() or extensions.has(name.get_extension().to_lower()):
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


static func list_subdirs(res_dir: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(res_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


## Reads width/height straight from the file header without decoding pixels.
## Supports PNG and GIF (the two formats this project deals in for browsing).
static func image_dimensions(res_path: String) -> Vector2i:
	var ext := res_path.get_extension().to_lower()
	if ext == "png":
		return _png_dimensions(res_path)
	if ext == "gif":
		return _gif_dimensions(res_path)
	return Vector2i(-1, -1)


static func _png_dimensions(res_path: String) -> Vector2i:
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return Vector2i(-1, -1)
	f.big_endian = true
	f.seek(16)
	var w := f.get_32()
	var h := f.get_32()
	f.close()
	return Vector2i(w, h)


static func _gif_dimensions(res_path: String) -> Vector2i:
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return Vector2i(-1, -1)
	f.seek(6)
	var w := f.get_16()
	var h := f.get_16()
	f.close()
	return Vector2i(w, h)


## Loads a preview texture for supported formats. Returns null if unsupported
## (e.g. GIF, which Godot cannot decode without an extra plugin) — callers
## should fall back to showing dimensions/metadata only.
static func load_preview_texture(res_path: String) -> Texture2D:
	var ext := res_path.get_extension().to_lower()
	if ext != "png" and ext != "jpg" and ext != "jpeg" and ext != "bmp" and ext != "webp":
		return null
	if not FileAccess.file_exists(res_path):
		return null
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
