extends Node
## M12: disconnect in the dungeon. With the host's own hero parked dead, the
## client's departure must be able to END the run (they were the last one
## standing) and clean up their hero puppet.


class Probe:
	extends Node

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
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

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_disconnect_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false)
		DungeonManager.pending["layout_seed"] = 999
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

		# Park the host's own hero dead so the client is the last one standing —
		# their drop must then end the run.
		(d.get("hero") as CombatHero).health.dead = true

		# The client drops after its dwell (Net.leave then quit).
		var left := await _wait_for(func() -> bool:
			return not (d.get("_net_hero_puppets") as Dictionary).has(2), 30.0)
		_expect(left, "client hero puppet was never cleaned up on drop")
		var ended := await _wait_for(func() -> bool: return bool(d.get("finished")), 10.0)
		_expect(ended, "run did not end when the last hero left")

		Net.leave()
		if failures.is_empty():
			print("NET_DISCONNECT_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DISCONNECT_PROBE_FAIL: ", failure)
			get_tree().quit(1)


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
