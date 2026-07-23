extends Node
## Windowed proof using the real shop, storage, workshop, and encyclopedia UI.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/item_size_consistency/"
	# Slots 2 and 3 are the two stands visible in the opening camera. Put the
	# catalog's 35px and 12px source extremes there for a direct visual proof.
	const ITEMS := ["bright_shard", "super_mushroom", "keychain", "deku_nut", "kingdom_key", "kh_potion"]

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		_reset_state()
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(0.3).timeout
		var shop = get_tree().current_scene
		shop.hud.set_process_unhandled_input(false)
		await get_tree().create_timer(1.4).timeout
		for i in mini(ITEMS.size(), InventoryManager.display.size()):
			shop.dev_set_display_item(i, ITEMS[i])
		await get_tree().create_timer(0.35).timeout
		_snap("01_normalized_shop_displays.png")

		shop._open_storage()
		await get_tree().create_timer(0.45).timeout
		_snap("02_normalized_storage_rows.png")
		_close_modal_layers(shop)
		shop.busy = false
		shop.player.frozen = false
		await get_tree().process_frame

		var workshop := WorkshopPanel.new()
		shop.add_child(workshop)
		await get_tree().create_timer(0.45).timeout
		_snap("03_normalized_workshop_rows.png")
		workshop.queue_free()
		await get_tree().process_frame

		var help := HelpEncyclopediaPanel.new()
		shop.add_child(help)
		await get_tree().create_timer(0.3).timeout
		help.open_category("Items")
		await get_tree().create_timer(0.45).timeout
		_snap("04_normalized_encyclopedia_items.png")
		print("ITEM_SIZE_CONSISTENCY_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
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
		for id in ITEMS:
			InventoryManager.add_item(id, 2)


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


	func _close_modal_layers(root: Node) -> void:
		for child in root.find_children("*", "CanvasLayer", true, false):
			if child is CanvasLayer and (child as CanvasLayer).layer >= 40:
				child.queue_free()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
