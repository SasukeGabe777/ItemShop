extends Node
## M7: town online. Host + client walk the same town — puppets track remote
## bodies, and the enter-shop gate only fires when the whole party is ready.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_town_client.json"

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
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		var town := get_tree().current_scene
		_expect(town != null and town.scene_file_path.ends_with("town.tscn"),
			"host did not reach town")

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_town_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

		# Client joins -> a puppet appears in the host's town and converges on
		# the client's parked position.
		var pupped := await _wait_for(func() -> bool:
			town = get_tree().current_scene
			return town != null and town.scene_file_path.ends_with("town.tscn") \
				and (town.get("_net_puppets") as Dictionary).has(2), 25.0)
		_expect(pupped, "client puppet never appeared in host town")
		if pupped:
			var p2: TownPlayer = (town.get("_net_puppets") as Dictionary).get(2)
			_expect(p2.manifest_override
				== PartyState.avatar_of(2),
				"online P2 selected character sprite was replaced")
			var sidekick: PatchFollower = \
				(town.get("_net_sidekicks") as Dictionary).get(2)
			_expect(sidekick != null and sidekick.target == p2 \
				and sidekick.manifest_path \
					== "res://assets/shared/effects/p2_sidekick.json",
				"online P2 fairy is not attached as a separate sidekick")
			var tracked := await _wait_for(func() -> bool:
				var pup: Node2D = (town.get("_net_puppets") as Dictionary).get(2)
				return is_instance_valid(pup) \
					and pup.global_position.distance_to(Vector2(123, 231)) < 10.0, 15.0)
			_expect(tracked, "client puppet never converged on (123, 231)")

		# Host readies the shop gate; the client's gate completes it.
		Net.request("party.gate", {"action_id": "enter_shop"})
		var in_shop := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("shop.tscn"), 25.0)
		_expect(in_shop, "gate completion never took the host to the shop")

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
			_expect(bool(report.get("town_seen", false)), "client never saw town")
			_expect(bool(report.get("host_puppet_seen", false)), "client never saw host puppet")
			_expect(bool(report.get("local_character_and_sidekick", false)),
				"client P2 did not keep its character plus fairy sidekick")
			_expect(String(report.get("final_scene", "")).ends_with("shop.tscn"),
				"client landed in %s" % report.get("final_scene"))

		Net.leave()
		if failures.is_empty():
			print("NET_TOWN_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_TOWN_PROBE_FAIL: ", failure)
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
