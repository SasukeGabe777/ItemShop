extends Node
## M5: parking. The host is mid-dungeon when a client joins — the client gets
## parked (kept connected, waiting), then welcomed into town when the party
## returns. Two-stage: scene changes free the current scene.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_park_client.json"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		GameState.reset_campaign()
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
		DungeonManager.plan_expedition("zelda", "link", [], false)
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var scene := get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("dungeon.tscn"),
			"host did not reach the dungeon")
		_expect(Net.current_scene_key() == "dungeon", "scene key lookup wrong")

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_park_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

		var parked_seen := await _wait_for(func() -> bool:
			return PartyState.players.has(2) \
				and bool(PartyState.player(2).get("parked", false)), 20.0)
		_expect(parked_seen, "host never parked the joiner")

		await get_tree().create_timer(0.5).timeout
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		_expect(not bool(PartyState.player(2).get("parked", true)),
			"seat 2 still parked after returning to town")

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
			_expect(bool(report.get("parked_fired", false)), "client parked signal never fired")
			_expect(String(report.get("park_reason", "")).contains("mid-expedition"),
				"park reason wrong: %s" % report.get("park_reason"))
			_expect(String(report.get("landed_scene", "")).ends_with("town.tscn"),
				"client landed in %s" % report.get("landed_scene"))
			_expect(int(report.get("index", 0)) == 2, "client index %s" % report.get("index"))

		Net.leave()
		if failures.is_empty():
			print("NET_PARK_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_PARK_PROBE_FAIL: ", failure)
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
