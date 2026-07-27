extends Node
## Full online dungeon progression regression.
##
## The host kills the authoritative population in every room while the client
## is the player that crosses each opened north door. Three seeded expeditions
## prove that clear detection, blocker removal, reliable clear events, remote
## player movement, room transitions, and the final boss all stay in sync.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_dungeon_full_run_client.json"
	const RUN_CONFIGS := [
		{"seed": 424242, "world": "kingdom_hearts", "host": "sora", "client": "link"},
		{"seed": 8675309, "world": "naruto", "host": "naruto", "client": "sora"},
		{"seed": 20260726, "world": "rotmg", "host": "archer", "client": "wizard"},
	]

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		_reset_campaign()
		_expect(Net.host_game("FullRunHost") == OK, "host_game failed")
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"res://tests/net_dungeon_full_run_client.tscn",
		])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) \
				and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		var host_runs: Array[Dictionary] = []
		for run_idx in RUN_CONFIGS.size():
			var run_result := await _play_run(run_idx, RUN_CONFIGS[run_idx])
			host_runs.append(run_result)
			if run_idx + 1 < RUN_CONFIGS.size():
				SceneRouter.go("town")
				await get_tree().create_timer(1.0).timeout

		var reported := await _wait_for(func() -> bool:
			return FileAccess.file_exists(REPORT_PATH), 35.0)
		_expect(reported, "client never wrote its full-run report")
		if reported:
			var file := FileAccess.open(REPORT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file = null
			var report: Dictionary = parsed if parsed is Dictionary else {}
			_expect(String(report.get("error", "")) == "",
				"client error: %s" % report.get("error"))
			var client_runs: Array = report.get("runs", [])
			_expect(client_runs.size() == RUN_CONFIGS.size(),
				"client recorded %d/%d runs" % [client_runs.size(), RUN_CONFIGS.size()])
			for i in range(mini(client_runs.size(), host_runs.size())):
				var client_run: Dictionary = client_runs[i]
				var host_run: Dictionary = host_runs[i]
				_expect(bool(client_run.get("finished", false)),
					"client run %d never saw expedition finish" % i)
				_expect((client_run.get("rooms", []) as Array).size()
					== int(host_run.get("layout_size", -1)),
					"client run %d saw rooms %s, host layout had %s" % [
						i, client_run.get("rooms"), host_run.get("layout_size")])

		Net.leave()
		if failures.is_empty():
			print("NET_DUNGEON_FULL_RUN_PROBE_PASS runs=%d" % RUN_CONFIGS.size())
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DUNGEON_FULL_RUN_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _play_run(run_idx: int, config: Dictionary) -> Dictionary:
		DungeonManager.plan_expedition_party(String(config["world"]), [
			{"player_index": 1, "hero_id": String(config["host"]), "consumables": []},
			{"player_index": 2, "hero_id": String(config["client"]), "consumables": []},
		], false)
		DungeonManager.pending["layout_seed"] = int(config["seed"])
		SceneRouter.go("dungeon")
		var arrived := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 15.0)
		_expect(arrived, "run %d host never reached dungeon" % run_idx)
		if not arrived:
			return {}
		var dungeon := get_tree().current_scene
		var layout: Array = dungeon.get("layout")
		var visited: Array[int] = [int(dungeon.get("room_index"))]
		var room_started := Time.get_ticks_msec()
		var last_room := int(dungeon.get("room_index"))
		print("full-run %d room %d/%d kind=%s" % [
			run_idx, last_room + 1, layout.size(), layout[last_room].get("kind")])
		var puppet_ready := await _wait_for(func() -> bool:
			return (dungeon.get("_net_hero_puppets") as Dictionary).has(2), 15.0)
		_expect(puppet_ready, "run %d client puppet never appeared" % run_idx)

		while not bool(dungeon.get("finished")):
			var room := int(dungeon.get("room_index"))
			if room != last_room:
				last_room = room
				room_started = Time.get_ticks_msec()
				visited.append(room)
				print("full-run %d room %d/%d kind=%s" % [
					run_idx, room + 1, layout.size(), layout[room].get("kind")])

			# Repeatedly kill the current authoritative population. Splitter
			# children appear synchronously and are picked up on the next tick.
			for enemy: Enemy in dungeon.call("_live_room_enemies"):
				enemy.take_packet({
					"damage": 999999, "knockback": 0.0,
					"source": dungeon.get("hero"),
				}, enemy.global_position)

			if bool(dungeon.get("door_open")):
				_expect(dungeon.get("door_blocker") == null,
					"run %d room %d opened but kept its blocker" % [run_idx, room])

			await get_tree().create_timer(0.1).timeout
			if Time.get_ticks_msec() - room_started > 12000:
				failures.append(
					"run %d stuck in room %d: door=%s live=%d blocker=%s" % [
						run_idx, room, dungeon.get("door_open"),
						(dungeon.call("_live_room_enemies") as Array).size(),
						dungeon.get("door_blocker")])
				break

		_expect(bool(dungeon.get("finished")), "run %d never finished" % run_idx)
		_expect(visited.size() == layout.size(),
			"run %d visited %s of %d rooms" % [run_idx, visited, layout.size()])
		return {"rooms": visited, "layout_size": layout.size()}


	func _reset_campaign() -> void:
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


	func _wait_for(condition: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(condition.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(condition.call())


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
