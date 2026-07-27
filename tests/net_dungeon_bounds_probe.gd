extends Node
## Online containment regression. A real client attempts to leave a closed
## room and then the open doorway at the wrong x coordinate. The host must see
## a bounded puppet, remain in the same room, and advance only for the valid
## centered north-door crossing.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_dungeon_bounds_client.json"
	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		var absolute_report := ProjectSettings.globalize_path(REPORT_PATH)
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(absolute_report)
		_reset_campaign()
		_expect(Net.host_game("BoundsHost") == OK, "host_game failed")
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"res://tests/net_dungeon_bounds_client.tscn",
		])
		_expect(pid > 0, "could not spawn bounds client")
		_expect(await _wait_for(func() -> bool:
			return PartyState.players.has(2) \
				and bool(PartyState.player(2).get("connected", false)), 20.0),
			"client never seated")

		DungeonManager.plan_expedition_party("kingdom_hearts", [
			{"player_index": 1, "hero_id": "sora", "consumables": []},
			{"player_index": 2, "hero_id": "link", "consumables": []},
		], false)
		DungeonManager.pending["layout_seed"] = 424242
		SceneRouter.go("dungeon")
		var arrived := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"),
			15.0)
		_expect(arrived, "host never reached dungeon")
		if not arrived:
			_finish()
			return
		var dungeon := get_tree().current_scene
		_expect(await _wait_for(func() -> bool:
			return (dungeon.get("_net_hero_puppets") as Dictionary).has(2), 15.0),
			"client puppet never appeared")
		Net.broadcast_scene_event("enter_room", {"idx": 1})
		_expect(await _wait_for(func() -> bool:
			return int(dungeon.get("room_index")) == 1 \
				and not bool(dungeon.get("door_open")), 8.0),
			"host did not enter closed combat room")

		_expect(await _wait_for(func() -> bool: return _client_phase() >= 1, 15.0),
			"client did not complete closed-room boundary attempts")
		await get_tree().create_timer(0.4).timeout
		var puppet := (dungeon.get("_net_hero_puppets") as Dictionary).get(2) as CombatHero
		_expect(int(dungeon.get("room_index")) == 1,
			"off-corridor client advanced the closed room")
		_expect(puppet != null and puppet.global_position.x >= 7.0 \
			and puppet.global_position.y >= 23.0,
			"host puppet escaped closed room at %s" % (
				puppet.global_position if puppet != null else Vector2.INF))

		var live: Array = dungeon.call("_live_room_enemies")
		_expect(not live.is_empty(), "online combat room had no enemies")
		if not live.is_empty():
			var enemy := live[0] as Enemy
			enemy.global_position = Vector2(-500, -500)
			await get_tree().physics_frame
			await get_tree().process_frame
			var radius := maxf(4.0, enemy.hit_radius)
			_expect(enemy.global_position.x >= radius \
				and enemy.global_position.y >= 16.0 + radius,
				"authoritative enemy escaped online room at %s" % enemy.global_position)
		for enemy: Enemy in dungeon.call("_live_room_enemies"):
			enemy.take_packet({"damage": 999999, "knockback": 0.0,
				"source": dungeon.get("hero")}, enemy.global_position)
		_expect(await _wait_for(func() -> bool: return bool(dungeon.get("door_open")), 10.0),
			"online room never opened")

		_expect(await _wait_for(func() -> bool: return _client_phase() >= 2, 15.0),
			"client did not complete open-door wrong-corridor attempt")
		await get_tree().create_timer(0.4).timeout
		_expect(int(dungeon.get("room_index")) == 1,
			"wrong-corridor client coordinate advanced open room")
		puppet = (dungeon.get("_net_hero_puppets") as Dictionary).get(2) as CombatHero
		_expect(puppet != null and puppet.global_position.x >= 7.0 \
			and puppet.global_position.y >= 23.0,
			"host puppet escaped beside open door at %s" % (
				puppet.global_position if puppet != null else Vector2.INF))

		_expect(await _wait_for(func() -> bool:
			return int(dungeon.get("room_index")) >= 2, 15.0),
			"valid remote north-door crossing did not advance")
		_expect(await _wait_for(func() -> bool: return _client_phase() >= 3, 10.0),
			"client did not confirm valid crossing")
		var report := _client_report()
		_expect(String(report.get("error", "")) == "",
			"client boundary failure: %s" % report.get("error"))
		_finish()


	func _client_phase() -> int:
		return int(_client_report().get("phase", 0))


	func _client_report() -> Dictionary:
		if not FileAccess.file_exists(REPORT_PATH):
			return {}
		var file := FileAccess.open(REPORT_PATH, FileAccess.READ)
		if file == null:
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		return parsed if parsed is Dictionary else {}


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


	func _finish() -> void:
		Net.leave()
		if failures.is_empty():
			print("NET_DUNGEON_BOUNDS_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DUNGEON_BOUNDS_PROBE_FAIL: ", failure)
			get_tree().quit(1)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
