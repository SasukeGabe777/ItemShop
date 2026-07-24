extends Node
## M11: online expedition lineup. The host opens the gates; both machines get
## their own LineupPanel, each picks its own hero + belt, and the host departs
## the whole party (fees + shared-stock validated) into one seeded dungeon.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_lineup_client.json"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		EconomyManager.gold = 5000
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		# pre-meet the heroes so departing doesn't queue a hero_met story scene
		GameState.meet_hero("sora")
		GameState.meet_hero("link")

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_lineup_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		SceneRouter.go("town")
		await get_tree().create_timer(2.0).timeout
		var town := get_tree().current_scene
		_expect(town != null and town.scene_file_path.ends_with("town.tscn"),
			"host did not reach town")

		# Host opens the gate lineup for kingdom_hearts (the chapter-1 world).
		await get_tree().create_timer(1.5).timeout  # let the client reach town
		Net.request("lineup.begin", {"world_id": "kingdom_hearts", "slice": false})
		var panel_up := await _wait_for(func() -> bool:
			var lp: Variant = town.get("_lineup_panel")
			return lp != null and is_instance_valid(lp), 15.0)
		_expect(panel_up, "host lineup panel never opened")

		# Host picks sora; the client picks link. Both readies complete the gate.
		await get_tree().create_timer(0.5).timeout
		Net.request("lineup.set", {"hero_id": "sora", "consumables": []})

		var in_dungeon := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 30.0)
		_expect(in_dungeon, "party never departed into the dungeon")
		var host_hero := ""
		var party_size := 0
		if in_dungeon:
			await get_tree().create_timer(1.0).timeout
			var d := get_tree().current_scene
			host_hero = String(d.get("hero").hero_id)
			party_size = (DungeonManager.pending.get("party", []) as Array).size()
		_expect(host_hero == "sora", "host hero wrong: %s" % host_hero)
		_expect(party_size == 2, "party plan has %d entries" % party_size)

		var reported := await _wait_for(func() -> bool:
			return FileAccess.file_exists(REPORT_PATH), 25.0)
		_expect(reported, "client never wrote its report")
		await get_tree().create_timer(0.5).timeout
		if reported:
			var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f = null
			var report: Dictionary = parsed if parsed is Dictionary else {}
			_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
			_expect(bool(report.get("lineup_seen", false)), "client never saw the lineup")
			_expect(bool(report.get("in_dungeon", false)), "client never reached the dungeon")
			_expect(String(report.get("my_hero", "")) == "link",
				"client hero wrong: %s" % report.get("my_hero"))

		Net.leave()
		if failures.is_empty():
			print("NET_LINEUP_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_LINEUP_PROBE_FAIL: ", failure)
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
