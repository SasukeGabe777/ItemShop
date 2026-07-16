class_name LocationLoader
## Instantiates a location authored in the Asset Factory's Locations tab
## (data/locations.json) as a runtime Node2D: tile sprites for the ground and
## decoration layers, StaticBody2D colliders for collision cells, and named
## Marker2D children for every gameplay marker (player_spawn, customer_spawn,
## item_stand_slot, door_exit, ...). This is the foundation the shop/town/
## dungeon scenes can adopt incrementally — nothing forces existing scenes
## onto it yet.


static func build_by_id(location_id: String) -> Node2D:
	var loc := ContentDatabase.get_location(location_id)
	return build(loc) if not loc.is_empty() else null


static func build(loc: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "Location_%s" % String(loc.get("id", "unknown"))
	var w := int(loc.get("width", 20))
	var h := int(loc.get("height", 12))
	var cell := int(loc.get("tile_size", 16))

	var tileset := _load_tileset(String(loc.get("tileset", "")))
	var sheet: Texture2D = tileset.get("texture")

	var layer_defs: Dictionary = loc.get("layers", {})
	var z := -10
	for layer_name in ["ground", "walls", "decoration"]:
		var arr: Array = layer_defs.get(layer_name, [])
		var layer_node := Node2D.new()
		layer_node.name = layer_name.capitalize()
		layer_node.z_index = z
		z += 1
		root.add_child(layer_node)
		if sheet == null:
			continue
		for i in mini(arr.size(), w * h):
			var t := int(arr[i])
			if t < 0:
				continue
			var spr := Sprite2D.new()
			spr.texture = sheet
			spr.region_enabled = true
			spr.region_rect = _tile_rect(tileset, t)
			spr.centered = false
			spr.position = Vector2((i % w) * cell, (i / w) * cell)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer_node.add_child(spr)

	var col: Array = loc.get("collision", [])
	for i in mini(col.size(), w * h):
		if int(col[i]) != 1:
			continue
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.position = Vector2((i % w) * cell + cell / 2.0, (i / w) * cell + cell / 2.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(cell, cell)
		shape.shape = rect
		body.add_child(shape)
		root.add_child(body)

	var markers_node := Node2D.new()
	markers_node.name = "Markers"
	root.add_child(markers_node)
	for m: Dictionary in loc.get("markers", []):
		var marker := Marker2D.new()
		var mtype := String(m.get("type", "marker"))
		marker.name = "%s_%d_%d" % [mtype, int(m.get("x", 0)), int(m.get("y", 0))]
		marker.position = Vector2(int(m.get("x", 0)) * cell + cell / 2.0, int(m.get("y", 0)) * cell + cell / 2.0)
		marker.set_meta("marker_type", mtype)
		if m.has("target"):
			marker.set_meta("target", String(m["target"]))
		markers_node.add_child(marker)
	return root


## All marker positions of one type, e.g. markers_of(root, "customer_spawn").
static func markers_of(location_root: Node2D, marker_type: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var markers_node := location_root.get_node_or_null("Markers")
	if markers_node == null:
		return out
	for child in markers_node.get_children():
		if String(child.get_meta("marker_type", "")) == marker_type:
			out.append((child as Marker2D).global_position)
	return out


static func _load_tileset(json_path: String) -> Dictionary:
	if json_path == "" or not FileAccess.file_exists(json_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.open(json_path, FileAccess.READ).get_as_text())
	if not (parsed is Dictionary):
		return {}
	var meta: Dictionary = parsed
	var sheet_path := String(meta.get("sheet", ""))
	var tex: Texture2D = null
	if ResourceLoader.exists(sheet_path):
		tex = load(sheet_path)
	elif FileAccess.file_exists(sheet_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	meta["texture"] = tex
	return meta


static func _tile_rect(tileset: Dictionary, index: int) -> Rect2:
	var ts: Array = tileset.get("tile_size", [16, 16])
	var cols := maxi(1, int(tileset.get("columns", 1)))
	var margin := int(tileset.get("margin", 0))
	var spacing := int(tileset.get("spacing", 0))
	return Rect2(
		margin + (index % cols) * (int(ts[0]) + spacing),
		margin + (index / cols) * (int(ts[1]) + spacing),
		int(ts[0]), int(ts[1]))
