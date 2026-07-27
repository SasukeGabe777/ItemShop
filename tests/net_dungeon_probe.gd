extends Node
## M8: dungeon core online. Host + client run the same seeded dungeon; both
## damage directions cross the wire correctly; walking out the door advances
## the whole party together; the host's finish reaches everyone.


class Probe:
	extends Node

	const REPORT_PATH := "user://net_dungeon_client.json"

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
			["--headless", "--path", proj, "res://tests/net_dungeon_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var seated := await _wait_for(func() -> bool:
			return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
		_expect(seated, "client never seated")

		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false)
		DungeonManager.pending["layout_seed"] = 424242
		DungeonManager.pending["party"] = [
			{"player_index": 1, "hero_id": "sora", "consumables": []},
			{"player_index": 2, "hero_id": "link", "consumables": []},
		]
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var d := get_tree().current_scene
		_expect(d != null and d.scene_file_path.ends_with("dungeon.tscn"),
			"host did not reach the dungeon")
		var my_sig: String = _layout_sig(d.get("layout"))
		_expect(String(d.get("hero").hero_id) == "sora", "host hero wrong")
		var has_pup := await _wait_for(func() -> bool:
			return (d.get("_net_hero_puppets") as Dictionary).has(2), 15.0)
		_expect(has_pup, "client hero puppet never spawned host-side")
		var pup: CombatHero = null
		if has_pup:
			pup = (d.get("_net_hero_puppets") as Dictionary)[2]
			_expect(String(pup.hero_id) == "link", "client puppet hero wrong: %s" % pup.hero_id)

		# Freeze the room's own enemies so the test stays deterministic.
		var enemy_id := ""
		for node in get_tree().get_nodes_in_group("enemies"):
			(node as Node).set_physics_process(false)
		for entry: Dictionary in (d.get("layout") as Array):
			var list: Array = entry.get("enemies", [])
			if not list.is_empty():
				enemy_id = String(list[0])
				break
		_expect(enemy_id != "", "layout has no enemies to test with")

		# 1. Parked target: the client swings at it; damage must land HERE.
		var mob: Enemy = d.dev_spawn_enemy(enemy_id, Vector2(300, 200))
		mob.set_physics_process(false)
		# Keep the assertion target alive even when the seeded enemy is a
		# low-HP one-shot; otherwise its freed capture looks like a missed RPC.
		mob.health.setup(999)
		var parked_eid := Replica.host_register(mob, "enemy",
			{"id": enemy_id, "hp": 999, "pos": [300.0, 200.0]})
		var hp0 := mob.health.hp
		var hit := await _wait_for(func() -> bool:
			return is_instance_valid(mob) and mob.health.hp < hp0, 25.0)
		_expect(hit, "client swing never landed on the host enemy")
		if hit:
			_expect(mob.last_attacker == 2, "kill credit tracked %d" % mob.last_attacker)

		# 2. A live chaser must maul the client's hero THROUGH its puppet here.
		(d.get("hero") as Node2D).global_position = Vector2(80, 60)
		var mob2: Enemy = d.dev_spawn_enemy(enemy_id, Vector2(480, 220))
		Replica.host_register(mob2, "enemy",
			{"id": enemy_id, "pos": [480.0, 220.0]})
		var pup_hurt := await _wait_for(func() -> bool:
			return pup != null and is_instance_valid(pup) \
				and pup.health.hp < pup.health.max_hp, 30.0)
		_expect(pup_hurt, "client hero hp never mirrored down host-side")
		if is_instance_valid(mob2):
			mob2.set_physics_process(false)

		# 3. Door: client walks out; the whole party must advance together.
		d.set("door_open", true)
		var advanced := await _wait_for(func() -> bool:
			return int(d.get("room_index")) == 1, 25.0)
		var pup_sm := pup.get_node_or_null("PuppetSmoother") as PuppetSmoother \
			if pup != null and is_instance_valid(pup) else null
		_expect(advanced, "party never advanced to room 1 (door=%s puppet=%s target=%s)" % [
			d.get("door_open"),
			pup.global_position if pup != null and is_instance_valid(pup) else Vector2.INF,
			pup_sm.target_pos if pup_sm != null else Vector2.INF])

		# 4. Finish flows to everyone.
		await get_tree().create_timer(1.0).timeout
		d._finish(true, false)
		await get_tree().create_timer(1.5).timeout
		_expect(bool(d.get("finished")), "host never finished")

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
			_expect(String(report.get("my_hero", "")) == "link", "client hero wrong")
			_expect(String(report.get("host_puppet_hero", "")) == "sora",
				"host puppet wrong on client")
			_expect(String(report.get("layout_sig", "")) == my_sig,
				"layouts diverged:\n  host   %s\n  client %s" % [my_sig, report.get("layout_sig")])
			_expect(float(report.get("meter_after_hit", 0.0)) > 0.0,
				"client meter never ticked on hit")
			_expect(int(report.get("target_eid", 0)) == parked_eid,
				"client swung at eid %s instead of parked eid %s" % [
					report.get("target_eid"), parked_eid])
			_expect(int(report.get("hp_after_touch", -1)) < int(report.get("max_hp", 0)),
				"client hp untouched by the chaser")
			_expect(bool(report.get("room1", false)), "client never reached room 1")
			_expect(bool(report.get("finished_seen", false)), "client never saw the finish")

		Net.leave()
		if failures.is_empty():
			print("NET_DUNGEON_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_DUNGEON_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	static func _layout_sig(layout: Array) -> String:
		var parts: Array[String] = []
		for entry: Dictionary in layout:
			parts.append("%s:%s" % [entry.get("kind"), str(entry.get("enemies"))])
		return "%d|%s" % [layout.size(), "|".join(parts)]


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
