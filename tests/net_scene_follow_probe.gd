extends Node
## M3: host+orchestrator proving that clients follow the host through scene
## changes (town then shop) in order. Two-stage per AGENT_GUIDE: the worker
## rides the tree root because SceneRouter.go frees the current scene.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_scene_client.json"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		GameState.reset_campaign()
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

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_scene_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

		var seated := await _wait_for(func() -> bool: return PartyState.count() >= 2, 20.0)
		_expect(seated, "client never seated")
		await get_tree().create_timer(1.0).timeout

		SceneRouter.go("town")
		await get_tree().create_timer(2.0).timeout
		var scene := get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("town.tscn"),
			"host did not reach town")

		SceneRouter.go("shop")
		await get_tree().create_timer(2.0).timeout
		scene = get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("shop.tscn"),
			"host did not reach shop")

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
			_expect(bool(report.get("joined", false)), "client never joined")
			var saw: Array = report.get("saw", [])
			var town_at := _index_ending(saw, "town.tscn")
			var shop_at := _index_ending(saw, "shop.tscn")
			_expect(town_at >= 0, "client never saw town (saw: %s)" % [saw])
			_expect(shop_at > town_at, "client scene order wrong (saw: %s)" % [saw])

		Net.leave()
		if failures.is_empty():
			print("NET_SCENE_FOLLOW_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_SCENE_FOLLOW_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _index_ending(list: Array, suffix: String) -> int:
		for i in range(list.size()):
			if String(list[i]).ends_with(suffix):
				return i
		return -1


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
