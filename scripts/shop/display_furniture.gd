class_name DisplayFurniture
extends Node2D
## A movable piece of shop display furniture built from a type definition in
## data/shop_furniture.json. Owns one or more display slots (contiguous
## InventoryManager.display indices starting at slot_base), its own
## interaction areas, an optional collision body, and edit-mode highlighting.
## Replaces the old hardcoded crate markers in the shop scene.

var uid: int = 0
var type_id: String = ""
var type_def: Dictionary = {}
var slot_base: int = 0
var slot_count: int = 1

var _item_sprites: Array[Sprite2D] = []
var _slot_offsets: Array[Vector2] = []
var _body_sprite: Sprite2D
var _collision_body: StaticBody2D
var _slot_highlight: Node2D


func setup(instance: Dictionary, def: Dictionary, p_slot_base: int, window_indices: Array[int]) -> void:
	uid = int(instance.get("uid", 0))
	type_id = String(instance.get("type", ""))
	type_def = def
	slot_base = p_slot_base
	var pos_arr: Array = instance.get("pos", [0, 0])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	add_to_group("dev_editable")
	set_meta("dev_object_type", "furniture")
	set_meta("dev_content_id", type_id)
	set_meta("dev_instance_id", uid)

	var slots: Array = def.get("display_slots", [[0, -12]])
	# decor pieces are pure appeal: no display slots, no interactions
	slot_count = 0 if bool(def.get("decor", false)) else maxi(1, slots.size())
	if bool(def.get("flat", false)):
		z_index = -1  # rugs and the like lie under everyone's feet

	_body_sprite = Sprite2D.new()
	_body_sprite.texture = _resolve_texture(def)
	# Content-Studio art comes in at source resolution; scale it down so the
	# drawn width matches the piece's footprint (art may be taller than the
	# footprint — the base sits on the footprint's bottom edge).
	var fp_arr: Array = def.get("size", [40, 24])
	var fp := Vector2(float(fp_arr[0]), float(fp_arr[1]))
	var tex := _body_sprite.texture
	var display_surface_y := 0.0  # 0 = use the data offsets as-is
	if tex != null and tex.get_width() > fp.x * 1.5:
		var k := fp.x / float(tex.get_width())
		var drawn_h := tex.get_height() * k
		_body_sprite.scale = Vector2(k, k)
		_body_sprite.position = Vector2(0, fp.y / 2.0 - drawn_h / 2.0)
		# tall art: items sit on the platform near the TOP of the sprite,
		# not at the data offsets tuned for the old 24px scenery pieces
		display_surface_y = fp.y / 2.0 - drawn_h + drawn_h * 0.22
	elif tex != null and tex.get_height() > fp.y:
		# native-size art taller than its footprint (decor plants, banners):
		# stand it on the footprint's bottom edge
		_body_sprite.position = Vector2(0, fp.y / 2.0 - tex.get_height() / 2.0)
	add_child(_body_sprite)

	if bool(def.get("blocks_movement", false)):
		_collision_body = StaticBody2D.new()
		_collision_body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var size_arr: Array = def.get("size", [40, 24])
		rect.size = Vector2(float(size_arr[0]), float(size_arr[1]))
		shape.shape = rect
		_collision_body.add_child(shape)
		add_child(_collision_body)

	for i in slot_count:
		var offset := Vector2(float(slots[i][0]), float(slots[i][1]))
		if display_surface_y != 0.0:
			offset.y = display_surface_y
		_slot_offsets.append(offset)
		var item_spr := Sprite2D.new()
		item_spr.name = "ItemSprite%d" % i
		item_spr.position = offset
		add_child(item_spr)
		_item_sprites.append(item_spr)

		var global_slot := slot_base + i
		var ic := InteractionComponent.new()
		ic.prompt = "Display slot %d" % (global_slot + 1)
		ic.action_id = "slot_%d" % global_slot
		ic.position = offset
		ic.add_to_group("interactables")
		add_child(ic)

		if global_slot in window_indices:
			var tag := UIKit.label("window", 7, UIKit.COL_DIM)
			tag.position = offset + Vector2(-14, -14)
			add_child(tag)

	refresh_items()


func _resolve_texture(def: Dictionary) -> Texture2D:
	var custom := String(def.get("sprite", ""))
	if custom != "" and ResourceLoader.exists(custom):
		return load(custom)
	var scenery_key := String(def.get("scenery", ""))
	if scenery_key != "":
		var tex := Scenery.texture_or_null(scenery_key)
		if tex != null:
			return tex
	var size_arr: Array = def.get("size", [40, 24])
	return PlaceholderFactory.furniture_texture(String(def.get("furniture_type", "shelf")),
		int(size_arr[0]) - 6, int(size_arr[1]) - 4)


func refresh_items() -> void:
	for i in _item_sprites.size():
		var global_slot := slot_base + i
		var id := ""
		if global_slot < InventoryManager.display.size():
			id = String(InventoryManager.display[global_slot])
		_item_sprites[i].texture = ContentDatabase.item_texture(id) if id != "" else null


## Bright physical marker for the slot whose stocking picker is open. This is
## especially useful on counters with two or three tightly packed item spots.
func set_slot_highlight(global_slot: int, on: bool = true) -> void:
	clear_slot_highlight()
	var local_slot := global_slot - slot_base
	if not on or local_slot < 0 or local_slot >= _slot_offsets.size():
		return
	var marker := Node2D.new()
	marker.name = "SlotHighlight"
	marker.position = _slot_offsets[local_slot]
	marker.z_index = 40
	marker.set_meta("global_slot", global_slot)
	add_child(marker)
	_slot_highlight = marker

	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0),
	])
	fill.color = Color(1.0, 0.84, 0.18, 0.52)
	marker.add_child(fill)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0), Vector2(0, -8),
	])
	outline.width = 2.0
	outline.default_color = Color(1.0, 0.96, 0.62)
	outline.antialiased = false
	marker.add_child(outline)

	var pulse := marker.create_tween().set_loops()
	pulse.tween_property(marker, "scale", Vector2(1.22, 1.22), 0.42).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(marker, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE)


func clear_slot_highlight() -> void:
	if is_instance_valid(_slot_highlight):
		_slot_highlight.queue_free()
	_slot_highlight = null


func slot_global_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for offset in _slot_offsets:
		out.append(position + offset)
	return out


## Where customers stand to look at each slot: on the floor in front of the
## piece (slot offsets can sit high on tall display art).
func browse_global_positions() -> Array[Vector2]:
	var size_arr: Array = type_def.get("size", [40, 24])
	var floor_y := float(size_arr[1]) / 2.0 + 4.0
	var out: Array[Vector2] = []
	for offset in _slot_offsets:
		out.append(position + Vector2(offset.x, floor_y))
	return out


func is_moveable() -> bool:
	return bool(type_def.get("is_moveable", true))


func footprint() -> Rect2:
	var size_arr: Array = type_def.get("size", [40, 24])
	var size := Vector2(float(size_arr[0]), float(size_arr[1]))
	return Rect2(position - size / 2.0, size)


## Edit-mode tinting: neutral highlight when selectable, green/red while being
## carried depending on placement validity.
func set_edit_highlight(on: bool) -> void:
	modulate = Color(1.2, 1.2, 0.9) if on else Color.WHITE


func set_ghost(valid: bool) -> void:
	modulate = Color(0.6, 1.2, 0.6, 0.8) if valid else Color(1.3, 0.5, 0.5, 0.8)


func clear_ghost() -> void:
	modulate = Color.WHITE
