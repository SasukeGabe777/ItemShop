extends Node
## Headless proof that attention furniture wins the exact visited slot, its
## effect is disclosed in the real catalog, and multi-slot pickers expose one
## unambiguous selected marker.

var failures: Array[String] = []


func _ready() -> void:
	_reset_state()
	_test_attention_targets_exact_slot()
	_test_catalog_and_slot_markers()
	if failures.is_empty():
		print("FURNITURE_ATTRACTION_PROBE_PASS")
	else:
		for message in failures:
			printerr("FURNITURE_ATTRACTION_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _reset_state() -> void:
	GameState.reset_campaign()
	GameState.tutorials_seen.append("first_shop_vertical_slice")
	GameState.shop_level = 5
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	ShopFurnitureManager.reset()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_attention_targets_exact_slot() -> void:
	ShopFurnitureManager.layout.clear()
	ShopFurnitureManager.add_instance("basic_item_stand", Vector2(200, 220))
	ShopFurnitureManager.add_instance("luxury_glass_display_case", Vector2(300, 220))
	InventoryManager.resize_display_slots(2)
	var item_id := ""
	for candidate: String in InventoryManager.storage:
		if bool(ContentDatabase.get_item(candidate).get("sellable", true)):
			item_id = candidate
			break
	_check(item_id != "", "starting inventory has no sellable item")
	if item_id == "":
		return
	# Deliberately duplicate the same stock: this was the case where the old
	# item-only result lost which furniture actually won the attention score.
	InventoryManager.display[0] = item_id
	InventoryManager.display[1] = item_id
	var cust := {"id": "attention_probe", "archetype": "adventurer", "budget": 999999, "world": ""}
	CustomerGen.rng.seed = 7331
	var normal_visits := 0
	var luxury_visits := 0
	for i in 300:
		var choice := ShopFurnitureManager.choose_display_slot_for_customer(cust)
		_check(String(choice.get("item_id", "")) == item_id, "customer lost duplicated item identity")
		if int(choice.get("slot", -1)) == 0:
			normal_visits += 1
		elif int(choice.get("slot", -1)) == 1:
			luxury_visits += 1
	_check(luxury_visits > normal_visits * 3,
		"+100%% attention did not draw clearly more visits (%d normal, %d luxury)" % [normal_visits, luxury_visits])
	print("ATTENTION_VISITS normal=", normal_visits, " luxury=", luxury_visits)


func _test_catalog_and_slot_markers() -> void:
	ShopFurnitureManager.layout.clear()
	ShopFurnitureManager.add_instance("green_counter", Vector2(320, 245))
	InventoryManager.resize_display_slots(3)
	var packed: PackedScene = load("res://scenes/shop/shop.tscn")
	var shop = packed.instantiate()
	add_child(shop)
	shop._open_furniture_catalog()
	var catalog_text := _all_label_text(shop)
	_check("+50% customer attention" in catalog_text, "premium furniture bonus missing from catalog description")
	_check("+100% customer attention" in catalog_text, "luxury furniture bonus missing from catalog description")
	_close_modal_layers(shop)
	shop.busy = false
	shop.player.frozen = false
	shop._open_slot_picker(1)
	var counter: DisplayFurniture = shop.furniture_nodes[0]
	var highlight := counter.get_node_or_null("SlotHighlight")
	_check(highlight != null, "selected Green Counter spot has no in-world highlight")
	if highlight != null:
		_check(int(highlight.get_meta("global_slot", -1)) == 1, "highlight points at the wrong global slot")
	var selected_markers := shop.find_children("SelectedSlotMarker", "Label", true, false)
	_check(selected_markers.size() == 1, "picker preview should have exactly one selected spot marker")
	var previews := shop.find_children("SlotPreview", "Control", true, false)
	_check(previews.size() == 1, "picker is missing its furniture slot preview")
	shop.queue_free()


func _all_label_text(root: Node) -> String:
	var lines: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func _close_modal_layers(root: Node) -> void:
	for child in root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer >= 40:
			child.queue_free()
