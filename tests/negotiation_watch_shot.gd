extends Node
## Windowed proof of the non-modal online negotiation picture-in-picture.

class Probe:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		InventoryManager.add_item("kh_potion", 3)
		InventoryManager.display[0] = "kh_potion"
		Net.host_game("Gabe")
		PartyState.players[2] = PartyState.make_seat(
			2, 0, "ShopBro", false)
		SceneRouter.go("shop")
		await get_tree().create_timer(2.0).timeout
		var shop: Node = get_tree().current_scene
		var customer := CustomerGen.runtime_named(
			ContentDatabase.get_named_customer("moogle_c"))
		shop.hud._show_negotiation_watch({
			"who": 2,
			"player_name": "ShopBro",
			"customer": customer,
			"item_id": "kh_potion",
			"quantity": 1,
			"market_value": 70,
			"selected_price": 92,
			"player_offer": 100,
			"customer_counter": 84,
			"status": "That's more than I'm willing to spend. Customer counters 84g",
		})
		var start_pos: Vector2 = shop.player.position
		Input.action_press("move_left")
		await get_tree().create_timer(0.5).timeout
		Input.action_release("move_left")
		print("NEGOTIATION_WATCH_PLAYER_MOVED=",
			shop.player.position.distance_to(start_pos) > 1.0)
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/negotiation_watch.png")
		print("NEGOTIATION_WATCH_SHOT_DONE")
		Net.leave()
		get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred(
		"res://scenes/ui/main_menu.tscn")
