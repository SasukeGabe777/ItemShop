extends Node
## Windowed Boom probe: announcement first, then a visibly crowded live shop.

class Probe:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		RelationshipManager.reset()
		ShopFurnitureManager.reset()
		InventoryManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		BoomManager.rng.seed = 31
		CustomerGen.rng.seed = 31
		BoomManager.force_boom("kids_adventure_day")
		SceneRouter.go("shop")
		await get_tree().create_timer(3.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var shop: Node = get_tree().current_scene
		var briefing := DayBriefing.show_report(shop)
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/boom_announcement.png")
		briefing.queue_free()
		await get_tree().create_timer(0.25).timeout
		var stock := ["super_mushroom", "yoshi_egg", "ramen_bowl", "poke_ball", "rare_candy", "one_up_mushroom"]
		for i in range(mini(stock.size(), InventoryManager.display.size())):
			InventoryManager.add_item(stock[i], 8)
			shop.dev_set_display_item(i, stock[i])
		shop.dev_open_shop()
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/boom_arrivals.png")
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/boom_crowd.png")
		print("BOOM_CUSTOMERS_TOTAL=", shop.session_summary.get("customers", 0))
		print("BOOM_LIVE_CUSTOMERS=", shop.live_customers.size())
		print("BOOM_SHOP_SHOT_DONE")
		get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
