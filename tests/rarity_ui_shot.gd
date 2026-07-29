extends Node
## Windowed pass for rarity labels/filters in the game's main item browsers.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/rarity_ui/"
	var failures: Array[String] = []


	func _ready() -> void:
		AudioManager.set_muted(true)
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		GameState.reset_campaign()
		GameState.admin_mode = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(5)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		SceneRouter.go("shop")
		await get_tree().create_timer(1.0).timeout
		var shop := get_tree().current_scene
		await _storage(shop)
		await _stocking(shop)
		await _workshop(shop)
		await _encyclopedia(shop)
		if failures.is_empty():
			print("RARITY_UI_SHOT_PASS folder=",
				ProjectSettings.globalize_path(SHOT_DIR))
		else:
			for message in failures:
				printerr("RARITY_UI_SHOT_FAIL: " + message)
		get_tree().quit(0 if failures.is_empty() else 1)


	func _storage(shop: Node) -> void:
		shop._open_storage(1)
		await get_tree().create_timer(0.3).timeout
		var layer := _top_modal(shop)
		_bounds(layer, "storage")
		_snap("01_storage_rarity.png")
		layer.queue_free()
		await get_tree().process_frame


	func _stocking(shop: Node) -> void:
		shop._open_slot_picker(0, 1)
		await get_tree().create_timer(0.3).timeout
		var layer := _top_modal(shop)
		_bounds(layer, "display stocking")
		_snap("02_display_stocking_rarity.png")
		layer.queue_free()
		await get_tree().process_frame


	func _workshop(shop: Node) -> void:
		var workshop := WorkshopPanel.new()
		shop.add_child(workshop)
		await get_tree().create_timer(0.3).timeout
		_bounds(workshop, "workshop")
		_snap("03_workshop_rarity.png")
		workshop.queue_free()
		await get_tree().process_frame


	func _encyclopedia(shop: Node) -> void:
		var book := HelpEncyclopediaPanel.new()
		shop.add_child(book)
		await get_tree().create_timer(0.3).timeout
		book.open_category("Items")
		await get_tree().create_timer(0.2).timeout
		_bounds(book, "encyclopedia")
		_snap("04_encyclopedia_rarity.png")
		book.queue_free()
		await get_tree().process_frame


	func _top_modal(root: Node) -> CanvasLayer:
		var found: CanvasLayer = null
		for child: Node in root.get_children():
			if child is CanvasLayer and (child as CanvasLayer).layer >= 40:
				found = child
		return found


	func _bounds(root: Node, label: String) -> void:
		check(root != null, "%s did not open" % label)
		if root == null:
			return
		var panels := root.find_children("*", "PanelContainer", true, false)
		var modal: PanelContainer = null
		for panel: PanelContainer in panels:
			if panel.get_parent() is CenterContainer:
				modal = panel
				break
		check(modal != null, "%s has no ornate panel" % label)
		if modal == null:
			return
		var rect := modal.get_global_rect()
		var viewport_size := get_viewport().get_visible_rect().size
		print("RARITY_BOUNDS ", label, " rect=", rect, " viewport=", viewport_size)
		check(rect.position.x >= -0.5 and rect.position.y >= -0.5
			and rect.end.x <= viewport_size.x + 0.5
			and rect.end.y <= viewport_size.y + 0.5,
			"%s extends outside the viewport: %s" % [label, rect])


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


	func check(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred(
		"res://scenes/ui/main_menu.tscn")
