extends Node
## Headless proof that item shoppers take one exact route and that opening any
## menu pauses customer brains without pausing the game tree.

var failures: Array[String] = []


func _ready() -> void:
	_reset_state()
	_test_direct_item_target_and_retarget()
	await _test_menu_pauses_only_customers()
	if failures.is_empty():
		print("SHOP_CUSTOMER_FLOW_PROBE_PASS")
	else:
		for message in failures:
			printerr("SHOP_CUSTOMER_FLOW_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _reset_state() -> void:
	GameState.reset_campaign()
	GameState.tutorials_seen.append("first_shop_vertical_slice")
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BoomManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()
	InventoryManager.resize_display_slots(2)
	InventoryManager.display[0] = "kh_potion"
	InventoryManager.display[1] = "dragon_ball"


func _customer_data(id: String) -> Dictionary:
	return {"id": id, "name": "Flow Probe", "archetype": "adventurer",
		"budget": 999999, "world": "kingdom_hearts", "named": false}


func _test_direct_item_target_and_retarget() -> void:
	var points: Array[Vector2] = [Vector2(200, 250), Vector2(320, 250)]
	var customer := ShopCustomer.new()
	add_child(customer)
	customer.setup(_customer_data("route_probe"), points, Vector2(320, 400),
		points[0], "kh_potion", 0)
	_check(customer._waypoints.size() == 1, "chosen item route contains random stand detours")
	_check(customer._waypoints[0] == points[0], "chosen item route does not end at its exact slot")
	InventoryManager.display[0] = ""
	CustomerGen.rng.seed = 20260722
	customer._retarget_if_interest_moved()
	_check(customer._preferred_slot_index == 1, "sold item did not retarget to the remaining display slot")
	_check(customer._waypoints.size() == 1 and customer._waypoints[0] == points[1],
		"replacement item route does not point to its actual stand")
	customer.queue_free()


func _test_menu_pauses_only_customers() -> void:
	ShopFurnitureManager.layout.clear()
	ShopFurnitureManager.add_instance("basic_item_stand", Vector2(260, 245))
	InventoryManager.resize_display_slots(1)
	InventoryManager.display[0] = "kh_potion"
	var packed: PackedScene = load("res://scenes/shop/shop.tscn")
	var shop = packed.instantiate()
	add_child(shop)
	var customer := ShopCustomer.new()
	shop.add_child(customer)
	customer.setup(_customer_data("pause_probe"), shop.browse_points, Vector2(320, 400),
		shop.browse_points[0], "kh_potion", 0)
	shop.live_customers.append(customer)
	customer._waypoints.clear()
	customer.brain.begin_browsing()
	var before := customer.brain.browse_time
	var modal_parts := UIKit.modal(shop, "Customer pause probe")
	shop._sync_customer_activity_pause()
	_check(customer.is_shop_activity_paused(), "visible menu did not pause live customer activity")
	customer._physics_process(0.75)
	_check(is_equal_approx(customer.brain.browse_time, before), "paused customer decision timer kept running")
	_check(not get_tree().paused, "customer menu pause incorrectly paused the entire game tree")
	(modal_parts[0] as CanvasLayer).queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	shop._sync_customer_activity_pause()
	_check(not customer.is_shop_activity_paused(), "customer activity did not resume after menu closed")
	customer._physics_process(0.25)
	_check(customer.brain.browse_time < before, "resumed customer decision timer did not advance")
	shop.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
