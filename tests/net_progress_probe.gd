extends Node
## Regression for the "dungeon stuck on the first room, no enemies" bug.
## Unlike net_dungeon_probe this does NO manual door/enemy intervention — it
## relies on the real flow: the empty start room must auto-open its door, the
## host walking out must advance the whole party, and the next room must
## actually spawn enemies (seen on host AND client).


class Probe:
	extends Node

	const REPORT_PATH := "user://net_progress_client.json"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
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
			["--headless", "--path", proj, "res://tests/net_progress_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		DungeonManager.plan_expedition_party("kingdom_hearts", [
			{"player_index": 1, "hero_id": "sora", "consumables": []},
			{"player_index": 2, "hero_id": "sora", "consumables": []},
		], false)  # false = normal multi-room layout, not the 2-room slice
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var d := get_tree().current_scene
		_expect(d != null and d.scene_file_path.ends_with("dungeon.tscn"),
			"host did not reach the dungeon")

		# THE REGRESSION: the empty start room must open its door on its own —
		# no manual poke. Before the fix, door_open stayed false forever.
		var opened := await _wait_for(func() -> bool: return bool(d.get("door_open")), 8.0)
		_expect(opened, "start room never opened its door (the stuck-on-room-1 bug)")

		# walk the host hero out the top door; the party must advance to room 1
		(d.get("hero") as Node2D).global_position = Vector2(320, 18)
		var advanced := await _wait_for(func() -> bool: return int(d.get("room_index")) >= 1, 15.0)
		_expect(advanced, "host never advanced past the start room")

		# the room the party advanced into must actually contain enemies
		var host_enemies := await _wait_for(func() -> bool:
			return not get_tree().get_nodes_in_group("enemies").is_empty(), 10.0)
		_expect(host_enemies, "no enemies spawned in the combat room (host)")

		var reported := await _wait_for(func() -> bool:
			return FileAccess.file_exists(REPORT_PATH), 30.0)
		_expect(reported, "client never wrote its report")
		await get_tree().create_timer(0.5).timeout
		if reported:
			var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f = null
			var report: Dictionary = parsed if parsed is Dictionary else {}
			_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
			_expect(int(report.get("reached_room", -1)) >= 1,
				"client never advanced past the start room (reached %s)" % report.get("reached_room"))
			_expect(int(report.get("enemies_seen", 0)) > 0,
				"client saw no enemy puppets in the combat room")

		Net.leave()
		if failures.is_empty():
			print("NET_PROGRESS_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_PROGRESS_PROBE_FAIL: ", failure)
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
