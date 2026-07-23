extends Node
## Windowed proof of the secret admin encyclopedia, unlimited entry flags, and
## visible Markdown export confirmation.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/admin_sprite_review/"

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		GameState.admin_mode = false
		GameState.admin_review_flags.clear()
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = 64
		GameState._input(event)
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.0).timeout
		var shop = get_tree().current_scene
		shop.hud.set_process_unhandled_input(false)
		var panel := HelpEncyclopediaPanel.new()
		shop.add_child(panel)
		panel.show_encyclopedia()
		await get_tree().create_timer(0.45).timeout
		_snap("01_admin_review_categories.png")
		var items := panel._entries("Items")
		var enemies := panel._entries("Enemies")
		var customers := panel._entries("Customers")
		for i in mini(3, items.size()):
			GameState.set_admin_review_flag("Items", String(items[i]["id"]), true)
		if not enemies.is_empty():
			GameState.set_admin_review_flag("Enemies", String(enemies[0]["id"]), true)
		if not customers.is_empty():
			GameState.set_admin_review_flag("Customers", String(customers[0]["id"]), true)
		panel.open_category("Items")
		await get_tree().create_timer(0.45).timeout
		_snap("02_admin_item_checklist.png")
		panel._export_admin_review()
		await get_tree().create_timer(0.35).timeout
		_snap("03_admin_export_confirmation.png")
		print("ADMIN_SPRITE_REVIEW_SHOT_DONE path=",
			ProjectSettings.globalize_path(HelpEncyclopediaPanel.ADMIN_EXPORT_PATH))
		get_tree().quit()


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
