extends Node
## Probe: enable 2P split-screen, load the town and the shop, screenshot both.
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		MultiplayerState.set_enabled(true)
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var town: Node = get_tree().current_scene
		town.player.position = Vector2(320, 200)
		town.player2.position = Vector2(420, 300)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_town.png")
		# P2 opens the market on their half only
		town._activate("market", 2)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_p2_market.png")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		print("SHOP scene=", shop, " player2=", shop.get("player2"), " p2vp=", MultiplayerState.p2_viewport())
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_shop.png")
		MultiplayerState.set_enabled(false)
		print("SPLIT_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
