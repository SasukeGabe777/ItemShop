extends Node
## Windowed probe for bright-white in-world interaction prompts in both the
## Crossroads lobby and the item shop.


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
		ZoomCamera.preferred_zoom = 1.5
		DirAccess.make_dir_recursive_absolute("user://screenshots/")

		SceneRouter.go("town")
		await get_tree().create_timer(1.2).timeout
		var town: Node = get_tree().current_scene
		town.player.position = Vector2(200, 196)
		await get_tree().create_timer(0.4).timeout
		_check_prompt(town.prompt, "town")
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/interaction_prompt_town.png")

		if not GameState.tutorials_seen.has("first_shop_vertical_slice"):
			GameState.tutorials_seen.append("first_shop_vertical_slice")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.2).timeout
		var shop: Node = get_tree().current_scene
		shop.player.position = Vector2(320, 166)
		await get_tree().create_timer(0.4).timeout
		_check_prompt(shop.prompt, "shop")
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/interaction_prompt_shop.png")
		print("INTERACTION_PROMPTS_SHOT_DONE")
		get_tree().quit()

	func _check_prompt(prompt: Label, where: String) -> void:
		var color := prompt.get_theme_color("font_color")
		var outline := prompt.get_theme_constant("outline_size")
		print("PROMPT ", where, " text=", prompt.text, " color=", color,
			" outline=", outline)
		if not prompt.visible or color != UIKit.COL_PROMPT or outline < 2:
			push_error("INTERACTION_PROMPT_FAIL: " + where)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
