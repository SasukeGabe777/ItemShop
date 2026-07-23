extends Node
## Windowed proof: a real negotiation freezes the next shopper in place, then
## that shopper resumes and walks to the exact slot containing their item.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/shop_customer_flow/"

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		_reset_state()
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.0).timeout
		var shop = get_tree().current_scene
		shop.hud.set_process_unhandled_input(false)
		var first := _add_customer(shop, "first_flow", "kh_potion", 0, Vector2(280, 370))
		var next := _add_customer(shop, "next_flow", "dragon_ball", 1, Vector2(360, 370))
		await get_tree().create_timer(0.25).timeout
		shop._on_negotiate_requested(first.data, "kh_potion")
		await get_tree().create_timer(0.45).timeout
		var frozen_at: Vector2 = next.position
		_snap("01_negotiation_freezes_next_customer.png")
		await get_tree().create_timer(0.8).timeout
		var frozen_delta := next.position.distance_to(frozen_at)
		_snap("02_customer_still_frozen.png")
		print("CUSTOMER_MENU_FREEZE_DELTA=", frozen_delta)
		shop._on_negotiation_finished({"result": Negotiation.RESULT_LEAVE, "message": ""})
		for panel in shop.find_children("*", "NegotiationPanel", true, false):
			panel.queue_free()
		await get_tree().create_timer(2.5).timeout
		var target: Vector2 = shop.browse_points[1]
		print("CUSTOMER_EXACT_SLOT_DISTANCE=", next.position.distance_to(target),
			" customer=", next.position, " target=", target)
		_snap("03_next_customer_at_exact_item_slot.png")
		print("SHOP_CUSTOMER_FLOW_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()


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
		ShopFurnitureManager.layout = [
			{"uid": 1, "type": "basic_item_stand", "pos": [250.0, 235.0]},
			{"uid": 2, "type": "basic_item_stand", "pos": [390.0, 235.0]},
		]
		InventoryManager.resize_display_slots(2)
		for id in ["kh_potion", "dragon_ball"]:
			InventoryManager.add_item(id, 2)
		InventoryManager.display[0] = "kh_potion"
		InventoryManager.display[1] = "dragon_ball"


	func _add_customer(shop: Node, id: String, item_id: String, slot: int,
			at: Vector2) -> ShopCustomer:
		var customer := ShopCustomer.new()
		shop.add_child(customer)
		customer.position = at
		var data := {"id": id, "name": id.capitalize(), "archetype": "adventurer",
			"budget": 999999, "world": "kingdom_hearts", "named": false}
		customer.setup(data, shop.browse_points, shop.ENTRANCE,
			shop.browse_points[slot], item_id, slot)
		customer.left.connect(func(me: ShopCustomer) -> void: shop.live_customers.erase(me))
		shop.live_customers.append(customer)
		return customer


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
