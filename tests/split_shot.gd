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
		# expedition partner-confirm: P2's world-side A press must fire it
		var confirmed := {"v": false}
		MultiplayerState.request_confirm("expedition", 2, "Join the expedition!", func() -> void: confirmed["v"] = true)
		var jev := InputEventJoypadButton.new()
		jev.device = 1
		jev.button_index = 0
		jev.pressed = true
		Input.parse_input_event(jev)
		await get_tree().process_frame
		await get_tree().process_frame
		var jev2: InputEventJoypadButton = jev.duplicate()
		jev2.pressed = false
		Input.parse_input_event(jev2)
		await get_tree().process_frame
		print("CONFIRM fired by P2 world press: ", confirmed["v"], "  pending cleared: ", MultiplayerState.pending_confirm.is_empty())
		# both players browse menus at the same time, each on their own half
		town._activate("market", 2)
		town._activate("gates", 1)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_p2_market.png")
		# same-menu lock: P1 must be refused while P2 holds the market
		var busy_before: bool = town.busy
		town._activate("market", 1)
		await get_tree().process_frame
		print("LOCK market busy_before=", busy_before, " after P1 tries (must stay true=gates only): ", town.busy,
			" owner=", town._menu_owner)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		print("SHOP scene=", shop, " player2=", shop.get("player2"), " p2vp=", MultiplayerState.p2_viewport())
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_shop.png")
		# co-op dungeon: both heroes on one shared screen
		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false, "sora")
		SceneRouter.go("dungeon")
		await get_tree().create_timer(1.6).timeout
		var dungeon: Node = get_tree().current_scene
		print("DUNGEON hero2=", dungeon.get("hero2"))
		get_viewport().get_texture().get_image().save_png("user://screenshots/split_dungeon.png")
		MultiplayerState.set_enabled(false)
		print("SPLIT_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
