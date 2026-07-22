extends Node
## Windowed visual proof for furniture effect descriptions and multi-slot
## stocking selection. Captures the real shop/catalog rather than a mock UI.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/furniture_attraction/"

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		_reset_state()
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(0.25).timeout
		var shop = get_tree().current_scene
		# A connected controller can otherwise open the pause menu while this
		# unattended visual probe is composing its shots.
		shop.hud.set_process_unhandled_input(false)
		await get_tree().create_timer(1.25).timeout

		shop._open_furniture_catalog()
		await get_tree().create_timer(0.45).timeout
		_snap("01_furniture_catalog_descriptions.png")
		var scrolls := shop.find_children("*", "ScrollContainer", true, false)
		if not scrolls.is_empty():
			var scroll := scrolls[-1] as ScrollContainer
			scroll.scroll_vertical = 100000
		await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		_snap("02_attention_bonus_descriptions.png")

		_close_modal_layers(shop)
		shop.busy = false
		shop.player.frozen = false
		await get_tree().process_frame
		shop._highlight_display_slot(1)
		await get_tree().create_timer(0.3).timeout
		_snap("03_green_counter_selected_spot.png")

		shop._open_slot_picker(1)
		await get_tree().create_timer(0.45).timeout
		_snap("04_green_counter_picker_preview.png")
		print("FURNITURE_ATTRACTION_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()


	func _reset_state() -> void:
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		# Level 2 proves the first attraction choices are already purchasable;
		# later tiers remain visible in the same catalog as locked previews.
		GameState.shop_level = 2
		TimeManager.reset(1)
		EconomyManager.reset()
		EconomyManager.gold = 9999
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		ShopFurnitureManager.layout.clear()
		ShopFurnitureManager.add_instance("green_counter", Vector2(320, 245))
		InventoryManager.resize_display_slots(3)
		for i in mini(3, InventoryManager.storage.size()):
			InventoryManager.display[i] = String(InventoryManager.storage.keys()[i])


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


	func _close_modal_layers(root: Node) -> void:
		for child in root.find_children("*", "CanvasLayer", true, false):
			if child is CanvasLayer and (child as CanvasLayer).layer >= 40:
				child.queue_free()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
