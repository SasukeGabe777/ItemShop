extends Node
## Headless proof that raw item PNG dimensions cannot leak into menu rows and
## that shop-floor sprites normalize visual weight without crowding counters.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	InventoryManager.reset()
	_test_menu_icons("fairy_harp_keyblade", "field_medkit")
	_test_live_catalog()
	_test_single_and_two_slot_caps()
	_test_world_sprites("fairy_harp_keyblade", "field_medkit")
	if failures.is_empty():
		print("ITEM_SIZE_CONSISTENCY_PROBE_PASS")
	else:
		for message in failures:
			printerr("ITEM_SIZE_CONSISTENCY_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


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
	InventoryManager.resize_display_slots(3)
	InventoryManager.display[0] = small_id
	InventoryManager.display[1] = large_id
	InventoryManager.display[2] = "great_ball"
	var furniture := DisplayFurniture.new()
	add_child(furniture)
	furniture.setup({"uid": 999, "type": "probe", "pos": [0, 0]}, {
		"size": [40, 24], "display_slots": [[-13, -12], [0, -12], [13, -12]],
		"furniture_type": "shelf",
	}, 0, [])
	var rendered_areas: Array[float] = []
	for i in 3:
		var sprite := furniture.get_node("ItemSprite%d" % i) as Sprite2D
		_check(sprite != null and sprite.texture != null, "display slot %d has no item art" % i)
		if sprite != null and sprite.texture != null:
			var visual := _visible_metrics(sprite.texture)
			var rendered_max: float = float(visual["max_edge"]) * sprite.scale.x
			var rendered_area: float = float(visual["alpha_area"]) * sprite.scale.x * sprite.scale.y
			rendered_areas.append(rendered_area)
			_check(rendered_max <= 11.01,
				"dense display slot %d exceeds its 11px cap at %.2fpx" % [i, rendered_max])
	if rendered_areas.size() == 3:
		var lightest: float = rendered_areas.min()
		var heaviest: float = rendered_areas.max()
		_check(heaviest / lightest < 2.0,
			"normalized visual weight still varies %.2fx" % (heaviest / lightest))
		print("ITEM_VISUAL_WEIGHT_RANGE light=%.2f heavy=%.2f ratio=%.2f" % [
			lightest, heaviest, heaviest / lightest])
	furniture.free()


func _test_single_and_two_slot_caps() -> void:
	InventoryManager.resize_display_slots(2)
	InventoryManager.display[0] = "fairy_harp_keyblade"
	InventoryManager.display[1] = "field_medkit"
	var single := DisplayFurniture.new()
	add_child(single)
	single.setup({"uid": 997, "type": "single_probe", "pos": [0, 0]}, {
		"size": [40, 24], "display_slots": [[0, -12]], "furniture_type": "shelf",
	}, 0, [])
	var single_sprite := single.get_node("ItemSprite0") as Sprite2D
	var single_metrics := _visible_metrics(single_sprite.texture)
	var single_edge: float = float(single_metrics["max_edge"]) * single_sprite.scale.x
	_check(is_equal_approx(single_edge, 16.0),
		"single-slot stand item renders at %.2fpx instead of 16px" % single_edge)
	single.free()
	var double := DisplayFurniture.new()
	add_child(double)
	double.setup({"uid": 998, "type": "double_probe", "pos": [0, 0]}, {
		"size": [40, 24], "display_slots": [[-10, -12], [10, -12]],
		"furniture_type": "shelf",
	}, 0, [])
	var double_sprite := double.get_node("ItemSprite0") as Sprite2D
	var double_metrics := _visible_metrics(double_sprite.texture)
	var double_edge: float = float(double_metrics["max_edge"]) * double_sprite.scale.x
	_check(is_equal_approx(double_edge, 14.0),
		"two-slot stand changed from its approved 14px cap: %.2fpx" % double_edge)
	double.free()


func _test_live_catalog() -> void:
	var lightest := INF
	var heaviest := 0.0
	var checked := 0
	for id: String in ContentDatabase.live_items:
		var sprite := Sprite2D.new()
		sprite.texture = ContentDatabase.item_texture(id)
		if sprite.texture == null:
			sprite.free()
			continue
		UIKit.fit_item_sprite(sprite)
		var visual := _visible_metrics(sprite.texture)
		var rendered_max: float = float(visual["max_edge"]) * sprite.scale.x
		var rendered_area: float = float(visual["alpha_area"]) * sprite.scale.x * sprite.scale.y
		_check(rendered_max <= 14.01,
			"%s exceeds the standard 14px cap at %.2fpx" % [id, rendered_max])
		lightest = minf(lightest, rendered_area)
		heaviest = maxf(heaviest, rendered_area)
		checked += 1
		sprite.free()
	_check(checked > 0, "live catalog has no measurable item art")
	if checked > 0:
		_check(heaviest / lightest < 2.3,
			"full-catalog visual weight still varies %.2fx" % (heaviest / lightest))
		print("ITEM_CATALOG_VISUAL_WEIGHT items=%d light=%.2f heavy=%.2f ratio=%.2f" % [
			checked, lightest, heaviest, heaviest / lightest])


func _visible_metrics(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	var used := image.get_used_rect()
	var alpha_area := 0.0
	for y in range(used.position.y, used.position.y + used.size.y):
		for x in range(used.position.x, used.position.x + used.size.x):
			alpha_area += image.get_pixel(x, y).a
	return {
		"max_edge": maxf(float(used.size.x), float(used.size.y)),
		"alpha_area": alpha_area,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
