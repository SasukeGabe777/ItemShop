extends Node
## Windowed proof using the real shop, storage, workshop, and encyclopedia UI.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/item_size_consistency/"
	# Mix visually dense round items with airy weapons so both single stands and
	# the opening counter expose any remaining size or crowding problem.
	const ITEMS := ["dragon_ball", "great_ball", "fairy_harp_keyblade", "field_medkit", "goku_plushie", "summoning_scroll"]

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
		_snap("01_visual_weight_shop_displays.png")

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
		# Keep both ordinary stands and a real three-slot counter inside the
		# opening camera so the dense-layout cap receives visual coverage.
		ShopFurnitureManager.layout = [
			{"uid": 1, "type": "basic_item_stand", "pos": [190.0, 246.0]},
			{"uid": 2, "type": "basic_item_stand", "pos": [278.0, 246.0]},
			{"uid": 3, "type": "green_counter", "pos": [366.0, 246.0]},
		]
		InventoryManager.resize_display_slots(ShopFurnitureManager.total_slot_count())
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
