extends Node
## Windowed proof of all selected moredecor pieces in the real shop and decor
## catalog. The root handoff survives SceneRouter replacing the menu scene.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/moredecor_furniture/"
	const WALL_PLACEMENTS := [
		["omori_brick_hearth", Vector2(160, 260)],
		["omori_arched_window", Vector2(240, 260)],
		["omori_stage_curtain", Vector2(335, 260)],
		["omori_haunted_portrait", Vector2(430, 260)],
		["omori_photo_garland", Vector2(510, 260)],
	]
	const FLOOR_PLACEMENTS := [
		["omori_ceiling_fan", Vector2(160, 225)],
		["omori_party_balloons", Vector2(230, 260)],
		["omori_tall_houseplant", Vector2(305, 285)],
		["omori_rose_sofa", Vector2(405, 285)],
		["omori_round_cafe_table", Vector2(505, 285)],
	]


	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		_reset_state()
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(3.0).timeout
		var shop = get_tree().current_scene
		shop.hud.set_process_unhandled_input(false)
		shop.player.position = Vector2(320, 250)
		await get_tree().create_timer(0.4).timeout
		_snap("01_moredecor_wall_decor.png")

		_set_layout(FLOOR_PLACEMENTS)
		shop.dev_rebuild_furniture()
		await get_tree().create_timer(0.4).timeout
		_snap("02_moredecor_floor_decor.png")

		shop._open_decor_catalog()
		await get_tree().create_timer(0.5).timeout
		_snap("03_moredecor_catalog_top.png")
		var scrolls := shop.find_children("*", "ScrollContainer", true, false)
		if not scrolls.is_empty():
			(scrolls[-1] as ScrollContainer).scroll_vertical = 100000
		await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		_snap("04_moredecor_catalog_bottom.png")
		print("MOREDECOR_FURNITURE_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()


	func _reset_state() -> void:
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		GameState.shop_level = 3
		TimeManager.reset(1)
		EconomyManager.reset()
		EconomyManager.gold = 99999
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		_set_layout(WALL_PLACEMENTS)
		InventoryManager.resize_display_slots(0)


	func _set_layout(placements: Array) -> void:
		ShopFurnitureManager.layout.clear()
		for placement: Array in placements:
			ShopFurnitureManager.add_instance(String(placement[0]), placement[1] as Vector2)


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
