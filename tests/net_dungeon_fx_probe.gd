extends Node
## M9: dungeon polish. Enemy projectiles replicate to clients as cosmetic
## bullets, remote action events reach the host for puppet replay, and a
## client's retreat request pulls the whole party out.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_dungeon_fx_client.json"

	var failures: Array[String] = []
	var _actions_from_2 := 0
	var _specials_from_2 := 0


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
		Replica.remote_player_event.connect(
			func(idx: int, event_name: String, _args: Dictionary) -> void:
				if idx == 2 and event_name == "action":
					_actions_from_2 += 1)
		Replica.remote_player_event.connect(
			func(idx: int, event_name: String, args: Dictionary) -> void:
				if idx == 2 and event_name == "action" \
						and String(args.get("a", "")) == "special":
					_specials_from_2 += 1)

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_dungeon_fx_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false)
		DungeonManager.pending["layout_seed"] = 424242
		DungeonManager.pending["party"] = [
			{"player_index": 1, "hero_id": "sora", "consumables": []},
			{"player_index": 2, "hero_id": "sora", "consumables": []},
		]
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var d := get_tree().current_scene
		_expect(d != null and d.scene_file_path.ends_with("dungeon.tscn"),
			"host did not reach the dungeon")
		# Exercise the room-transition race directly: the boss and its replay
		# must survive on the client after both machines rebuild room_root.
		Net.broadcast_scene_event("enter_room", {"idx": d.get("layout").size() - 1})
		await get_tree().create_timer(1.0).timeout
		for node in get_tree().get_nodes_in_group("enemies"):
			(node as Node).set_physics_process(false)
		(d.get("hero") as Node2D).global_position = Vector2(80, 60)

		# A shooter parked near where the client will stand.
		var shooter_id := ""
		for id: String in ContentDatabase.enemies:
			var behavior := String(ContentDatabase.enemies[id].get("behavior", ""))
			if behavior == "shooter" or behavior == "skitter_shooter":
				shooter_id = id
				break
		_expect(shooter_id != "", "no shooter enemy in the database")
		var mob: Enemy = d.dev_spawn_enemy(shooter_id, Vector2(350, 200))
		Replica.host_register(mob, "enemy", {"id": shooter_id, "pos": [350.0, 200.0]})

		# The client swings 3 times, then retreats the party.
		var acted := await _wait_for(func() -> bool: return _actions_from_2 >= 2, 40.0)
		_expect(acted, "client action events never arrived (%d)" % _actions_from_2)
		var special_fx := await _wait_for(func() -> bool:
			if _specials_from_2 < 1:
				return false
			for child in d.find_children("*", "", true, false):
				if child is Projectile \
						and int((child as Projectile).packet.get("damage", -1)) == 0:
					return true
			return false, 10.0)
		_expect(special_fx,
			"remote special arrived but its cosmetic projectile was not visible")
		var done := await _wait_for(func() -> bool: return bool(d.get("finished")), 30.0)
		_expect(done, "client retreat never ended the run")

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
			_expect(bool(report.get("eproj_seen", false)),
				"client never saw a replicated enemy projectile")
			_expect(bool(report.get("boss_seen", false)),
				"client never saw the replicated boss")
			_expect(bool(report.get("boss_visible", false)),
				"client boss puppet was not visibly rendered")
			_expect(bool(report.get("finished_after_retreat", false)),
				"client did not see the finish after retreating")

		Net.leave()
		if failures.is_empty():
			print("NET_DUNGEON_FX_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DUNGEON_FX_PROBE_FAIL: ", failure)
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
