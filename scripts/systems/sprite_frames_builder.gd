class_name SpriteFramesBuilder
## Builds SpriteFrames resources from sprite-sheet manifests (see
## assets/*/manifests/*.json). Used by the game at runtime and by the sprite
## importer tool for .tres export.


static func from_manifest_path(manifest_path: String) -> SpriteFrames:
	if not FileAccess.file_exists(manifest_path):
		return null
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return null
	return from_manifest(parsed)


static func from_manifest(manifest: Dictionary) -> SpriteFrames:
	var sheet_path := String(manifest.get("sheet", ""))
	var tex: Texture2D = null
	if sheet_path.begins_with("res://") and ResourceLoader.exists(sheet_path):
		tex = load(sheet_path)
	elif FileAccess.file_exists(sheet_path):
		var img := Image.load_from_file(sheet_path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		return null
	return build(tex, manifest)


static func build(sheet: Texture2D, manifest: Dictionary) -> SpriteFrames:
	var grid: Dictionary = manifest.get("grid", {})
	var fw := int(grid.get("frame_width", 32))
	var fh := int(grid.get("frame_height", 32))
	var cols := int(grid.get("columns", maxi(1, sheet.get_width() / fw)))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var anims: Dictionary = manifest.get("animations", {})
	for anim_name: String in anims:
		var spec: Dictionary = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(spec.get("fps", 6)))
		frames.set_animation_loop(anim_name, bool(spec.get("loop", true)))
		# an animation may use explicit pixel rects instead of grid indices
		for r in spec.get("rects", []):
			var at_rect := AtlasTexture.new()
			at_rect.atlas = sheet
			at_rect.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			frames.add_frame(anim_name, at_rect)
		for frame_idx in spec.get("frames", []):
			var idx := int(frame_idx)
			var row := int(floor(float(idx) / float(cols)))
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(float(idx % cols) * fw, float(row) * fh, fw, fh)
			frames.add_frame(anim_name, at)
	return frames


## Variable-rectangle slicing: manifest animations may specify "rects":
## [[x,y,w,h], ...] instead of grid frame indices.
static func build_rects(sheet: Texture2D, anims: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in anims:
		var spec: Dictionary = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(spec.get("fps", 6)))
		frames.set_animation_loop(anim_name, bool(spec.get("loop", true)))
		for r in spec.get("rects", []):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			frames.add_frame(anim_name, at)
	return frames
