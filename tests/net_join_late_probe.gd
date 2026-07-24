extends Node
## M3: late join. The host is already mid-campaign (day 3, known gold) inside
## the shop BEFORE the client connects; the welcome snapshot + scene follow
## must land the client in the shop with identical state.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_late_client.json"

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
		EconomyManager.gold = 1234
		TimeManager.day = 3

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var scene := get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("shop.tscn"),
			"host did not reach shop before the client joined")

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_late_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

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
			_expect(String(report.get("scene", "")).ends_with("shop.tscn"),
				"client landed in %s" % report.get("scene"))
			_expect(int(report.get("gold", -1)) == 1234,
				"client gold %s != 1234" % report.get("gold"))
			_expect(int(report.get("day", -1)) == 3,
				"client day %s != 3" % report.get("day"))

		Net.leave()
		if failures.is_empty():
			print("NET_JOIN_LATE_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_JOIN_LATE_PROBE_FAIL: ", failure)
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
