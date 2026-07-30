extends Node
## Windowed proof of the refreshed first-shop guide, starter furniture, and
## Storage / Expand Shop landmark banners.

const SHOT_DIR := "user://screenshots/new_game_shop_polish/"


class Probe:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		GameState.reset_campaign()
		GameState.campaign_active = true
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.4).timeout
		_snap("01_first_shop_guide.png")
		var shop := get_tree().current_scene
		var begin := _button_named(shop, "Begin stocking")
		if begin != null:
			begin.pressed.emit()
		await get_tree().create_timer(0.4).timeout
		# Stand near the three top-wall interactions so their sprites and
		# landmark banners are inside the same player-facing camera view.
		shop.player.position = Vector2(320, 190)
		await get_tree().create_timer(0.4).timeout
		_snap("02_starter_shop_landmarks.png")
		print("NEW_GAME_SHOP_POLISH_SHOT_DONE folder=",
			ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()

	func _button_named(root: Node, text: String) -> Button:
		for node: Node in root.find_children("*", "Button", true, false):
			var button := node as Button
			if button.text == text:
				return button
		return null

	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred(
		"res://scenes/ui/main_menu.tscn")
