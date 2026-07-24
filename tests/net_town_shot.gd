extends Node
## M7 windowed screenshot: host in town with a joined client's puppet visible,
## both wearing colored name labels. Run WINDOWED.


class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/net_town/"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		_expect(Net.host_game("Gabe") == OK, "host_game failed")
		SceneRouter.go("town")
		await get_tree().create_timer(2.0).timeout

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_lobby_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

		var pupped := await _wait_for(func() -> bool:
			var town := get_tree().current_scene
			return town != null and town.scene_file_path.ends_with("town.tscn") \
				and (town.get("_net_puppets") as Dictionary).has(2), 25.0)
		_expect(pupped, "client puppet never appeared")
		# both bodies boot on the same spawn tile — separate them for the shot
		var town := get_tree().current_scene
		(town.get("player") as Node2D).global_position = Vector2(260, 300)
		await get_tree().create_timer(1.0).timeout
		await _save_shot("01_town_two_players.png")

		Net.leave()
		if failures.is_empty():
			print("NET_TOWN_SHOT_PASS shots=%s" % ProjectSettings.globalize_path(SHOT_DIR))
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_TOWN_SHOT_FAIL: ", failure)
			get_tree().quit(1)


	func _save_shot(filename: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(SHOT_DIR + filename)
		_expect(error == OK, "could not save screenshot %s" % filename)


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
