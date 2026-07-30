extends Node
## Either couch player may cross the shop threshold and carry the shared party
## back to town; the partner does not need to stand on the same screen edge.


class Probe:
	extends Node

	var failures: Array[String] = []

	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		BridgeManager.reset()
		ShopFurnitureManager.reset()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		DayBriefing.last_shown_day = TimeManager.day
		MultiplayerState.set_enabled(true)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.2).timeout
		var shop := get_tree().current_scene
		_check(shop != null and shop.scene_file_path.ends_with("shop.tscn"),
			"couch party never entered the shop")
		if shop != null and shop.scene_file_path.ends_with("shop.tscn"):
			shop.player2.position = Vector2(320, 280)
			shop.player.position = Vector2(320, shop.EXIT_Y + 4.0)
			await get_tree().create_timer(0.5).timeout
		var after_exit := get_tree().current_scene
		_check(after_exit != null
				and after_exit.scene_file_path.ends_with("town.tscn"),
			"shop exit still waits for couch P2 at the doorway")
		MultiplayerState.set_enabled(false)
		if failures.is_empty():
			print("SHOP_EXIT_COOP_PROBE_PASS")
		else:
			for message: String in failures:
				printerr("SHOP_EXIT_COOP_PROBE_FAIL: " + message)
		get_tree().quit(0 if failures.is_empty() else 1)

	func _check(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred(
		"res://scenes/ui/main_menu.tscn")
