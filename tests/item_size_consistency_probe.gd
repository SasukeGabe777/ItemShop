extends Node
## Headless proof that raw item PNG dimensions cannot leak into menu rows or
## shop display furniture. The live catalog currently spans 12px to 35px.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	InventoryManager.reset()
	var extremes := _source_extremes()
	_check(not extremes.is_empty(), "live item catalog has no textured items")
	if not extremes.is_empty():
		_test_menu_icons(String(extremes["small_id"]), String(extremes["large_id"]))
		_test_world_sprites(String(extremes["small_id"]), String(extremes["large_id"]))
	if failures.is_empty():
		print("ITEM_SIZE_CONSISTENCY_PROBE_PASS")
	else:
		for message in failures:
			printerr("ITEM_SIZE_CONSISTENCY_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _source_extremes() -> Dictionary:
	var small_id := ""
	var large_id := ""
	var small_max := INF
	var large_max := 0.0
	for id: String in ContentDatabase.live_items:
		var texture := ContentDatabase.item_texture(id)
		if texture == null:
			continue
		var source_max := maxf(float(texture.get_width()), float(texture.get_height()))
		if source_max < small_max:
			small_max = source_max
			small_id = id
		if source_max > large_max:
			large_max = source_max
			large_id = id
	print("ITEM_SOURCE_RANGE small=", small_id, " ", small_max,
		"px large=", large_id, " ", large_max, "px")
	return {} if small_id == "" or large_id == "" else {
		"small_id": small_id, "large_id": large_id,
		"small_max": small_max, "large_max": large_max,
	}


func _test_menu_icons(small_id: String, large_id: String) -> void:
	for id in [small_id, large_id]:
		var icon := UIKit.item_icon(id)
		_check(icon.custom_minimum_size == Vector2(24, 24), "%s menu icon lost its 24px box" % id)
		_check(icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "%s menu icon still inherits native size" % id)
		_check(icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s menu icon distorts its art" % id)
		var row := UIKit.item_row(id, "probe", "", Callable())
		var row_icon := row.get_child(0) as TextureRect
		_check(row_icon.custom_minimum_size == Vector2(18, 18), "%s shared row icon lacks the normalized box" % id)
		icon.free()
		row.free()


func _test_world_sprites(small_id: String, large_id: String) -> void:
	InventoryManager.resize_display_slots(2)
	InventoryManager.display[0] = small_id
	InventoryManager.display[1] = large_id
	var furniture := DisplayFurniture.new()
	add_child(furniture)
	furniture.setup({"uid": 999, "type": "probe", "pos": [0, 0]}, {
		"size": [60, 24], "display_slots": [[-12, -12], [12, -12]],
		"furniture_type": "shelf",
	}, 0, [])
	for i in 2:
		var sprite := furniture.get_node("ItemSprite%d" % i) as Sprite2D
		_check(sprite != null and sprite.texture != null, "display slot %d has no item art" % i)
		if sprite != null and sprite.texture != null:
			var rendered_max := maxf(sprite.texture.get_width() * sprite.scale.x,
				sprite.texture.get_height() * sprite.scale.y)
			_check(is_equal_approx(rendered_max, 18.0),
				"display slot %d renders at %.2fpx instead of 18px" % [i, rendered_max])
	furniture.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
