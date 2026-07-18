extends Node
## Probe: set up a fresh campaign state (no story scenes fired, no save
## writes), enter town, screenshot the upper and lower plaza.
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
		# deterministic events so the briefing + market trend colors are visible
		MarketManager.active_events = [
			{"id": "weapon_boom", "days_left": 2},
			{"id": "mushroom_oversupply", "days_left": 3},
		]
		DayBriefing.last_shown_day = TimeManager.day  # suppress auto-popup for clean town shots
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var town: Node = get_tree().current_scene
		town.player.position = Vector2(320, 200)
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/town_upper.png")
		town.player.position = Vector2(320, 370)
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/town_lower.png")
		var briefing := DayBriefing.show_report(town)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/town_briefing.png")
		briefing.queue_free()
		await get_tree().create_timer(0.2).timeout
		town.add_child(MarketPanel.new())
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/town_market.png")
		print("CATALOG=", MarketManager.wholesale_catalog().size())
		print("TOWN_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
