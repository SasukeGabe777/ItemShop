extends Node
## M8 windowed screenshot: host + client hero puppet + a live enemy in one
## dungeon room, name labels and HUD visible. Run WINDOWED.


class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/net_dungeon/"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		GameState.reset_campaign()
		GameState.campaign_active = true
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
		_expect(Net.host_game("Gabe") == OK, "host_game failed")

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_lobby_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false)
		DungeonManager.pending["layout_seed"] = 424242
		DungeonManager.pending["party"] = [
			{"player_index": 1, "hero_id": "sora", "consumables": []},
			{"player_index": 2, "hero_id": "link", "consumables": []},
		]
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var d := get_tree().current_scene
		_expect(d != null and d.scene_file_path.ends_with("dungeon.tscn"),
			"host did not reach the dungeon")
		var pupped := await _wait_for(func() -> bool:
			return (d.get("_net_hero_puppets") as Dictionary).has(2), 15.0)
		_expect(pupped, "client hero puppet never appeared")
		# Stage a real combat room: the fixed room camera must show the complete
		# north exit below the HUD while both heroes and enemies remain visible.
		Net.broadcast_scene_event("enter_room", {"idx": 1})
		await get_tree().create_timer(1.0).timeout
		(d.get("hero") as Node2D).global_position = Vector2(280, 190)
		await get_tree().create_timer(1.0).timeout
		await _save_shot("01_dungeon_party.png")

		# Kill the authoritative room population. The resulting persistent
		# ornate banner is the player's unambiguous "door is open" signal.
		for node: Node in d.call("_live_room_enemies"):
			var enemy := node as Enemy
			enemy.take_packet({"damage": 999999, "knockback": 0.0, "source": d.get("hero")},
				enemy.global_position)
		var cleared := await _wait_for(func() -> bool: return bool(d.get("door_open")), 10.0)
		_expect(cleared, "combat room never cleared")
		await get_tree().create_timer(0.5).timeout
		await _save_shot("02_room_cleared.png")

		Net.leave()
		if failures.is_empty():
			print("NET_DUNGEON_SHOT_PASS shots=%s" % ProjectSettings.globalize_path(SHOT_DIR))
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DUNGEON_SHOT_FAIL: ", failure)
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
