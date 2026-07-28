extends Node
## Hard room-boundary regression for local heroes, couch heroes and enemies.
## Direct out-of-bounds placement simulates dash/knockback/teleport overshoot;
## the dungeon must recover every edge and preserve only the open north exit.


class Probe:
	extends Node

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.5).timeout
		_reset_campaign()
		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false)
		DungeonManager.pending["layout_seed"] = 424242
		SceneRouter.go("dungeon")
		var arrived := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"),
			10.0)
		_expect(arrived, "did not reach dungeon")
		if not arrived:
			_finish()
			return

		var dungeon := get_tree().current_scene
		dungeon.call("_enter_room", 1)
		await get_tree().physics_frame
		var hero: CombatHero = dungeon.get("hero")
		_expect(hero != null, "local hero missing")
		_expect(not bool(dungeon.get("door_open")), "combat room unexpectedly open")

		var hero_cases := [
			{"at": Vector2(-500, 180), "check": func(p: Vector2) -> bool: return p.x >= 7.0,
				"name": "hero left"},
			{"at": Vector2(1200, 180), "check": func(p: Vector2) -> bool: return p.x <= 633.0,
				"name": "hero right"},
			{"at": Vector2(320, 900), "check": func(p: Vector2) -> bool: return p.y <= 377.0,
				"name": "hero bottom"},
			{"at": Vector2(320, -500), "check": func(p: Vector2) -> bool: return p.y >= 23.0,
				"name": "hero closed north door"},
		]
		for test: Dictionary in hero_cases:
			hero.global_position = test["at"]
			await get_tree().physics_frame
			_expect((test["check"] as Callable).call(hero.global_position),
				"%s escaped at %s" % [test["name"], hero.global_position])

		var live: Array = dungeon.call("_live_room_enemies")
		_expect(not live.is_empty(), "combat room has no enemy for bounds checks")
		if not live.is_empty():
			var enemy := live[0] as Enemy
			enemy.set_physics_process(false)
			var radius := maxf(4.0, enemy.hit_radius)
			var enemy_cases := [
				{"at": Vector2(-500, 180), "ok": func(p: Vector2) -> bool:
					return p.x >= radius, "name": "enemy left"},
				{"at": Vector2(1200, 180), "ok": func(p: Vector2) -> bool:
					return p.x <= 640.0 - radius, "name": "enemy right"},
				{"at": Vector2(320, 900), "ok": func(p: Vector2) -> bool:
					return p.y <= 384.0 - radius, "name": "enemy bottom"},
				{"at": Vector2(320, -500), "ok": func(p: Vector2) -> bool:
					return p.y >= 16.0 + radius, "name": "enemy north gap"},
			]
			for test: Dictionary in enemy_cases:
				enemy.global_position = test["at"]
				await get_tree().physics_frame
				_expect((test["ok"] as Callable).call(enemy.global_position),
					"%s escaped at %s radius=%s" % [
						test["name"], enemy.global_position, radius])

		# Open-door exception: a hero outside the corridor stays contained and
		# cannot advance; a hero centered in the corridor reaches the trigger
		# while their body remains inside the room rectangle.
		dungeon.set("door_open", true)
		hero.global_position = Vector2(-500, -500)
		dungeon.call("_enforce_room_bounds")
		_expect(hero.global_position.x >= 7.0 and hero.global_position.y >= 23.0,
			"open-door off-corridor hero escaped at %s" % hero.global_position)
		_expect(not bool(dungeon.call("_any_hero_past_exit")),
			"off-corridor coordinate advanced the room")
		hero.global_position = Vector2(320, -500)
		dungeon.call("_enforce_room_bounds")
		_expect(hero.global_position.y >= 7.0 and hero.global_position.y < 16.0,
			"valid exit did not stay in bounded trigger strip: %s" % hero.global_position)
		_expect(bool(dungeon.call("_any_hero_past_exit")),
			"valid centered exit was rejected")
		dungeon.set("door_open", false)

		# Clearing a room starts a full ten-second fallback. With every hero
		# standing away from the door it must hold before the deadline, then
		# advance the entire room through the normal transition path.
		hero.global_position = Vector2(320, 192)
		var cleared_room := int(dungeon.get("room_index"))
		dungeon.call("_apply_room_cleared", cleared_room)
		_expect(is_equal_approx(
			float(dungeon.get("_room_clear_auto_advance_left")), 10.0),
			"room clear did not start the 10-second auto-advance timer")
		dungeon.call("_process", 9.5)
		_expect(int(dungeon.get("room_index")) == cleared_room,
			"room auto-advanced before ten seconds")
		dungeon.call("_process", 0.6)
		_expect(int(dungeon.get("room_index")) == cleared_room + 1,
			"room did not auto-advance after ten seconds")

		_finish()


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
		if failures.is_empty():
			print("DUNGEON_BOUNDS_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("DUNGEON_BOUNDS_PROBE_FAIL: ", failure)
			get_tree().quit(1)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
