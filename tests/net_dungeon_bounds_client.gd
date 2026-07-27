extends Node
## Client half of net_dungeon_bounds_probe.


class Worker:
	extends Node

	const REPORT_PATH := "user://net_dungeon_bounds_client.json"
	var report := {"phase": 0, "error": ""}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "BoundsClient")
		if not await _wait_for(func() -> bool: return Net.my_index > 0, 10.0):
			_fail("no welcome")
			return
		if not await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn") \
				and int(scene.get("room_index")) == 1, 20.0):
			_fail("never reached combat room")
			return
		var dungeon := get_tree().current_scene
		var hero: CombatHero = dungeon.get("hero")
		if hero == null:
			_fail("local hero missing")
			return

		var closed_cases := [
			{"at": Vector2(-500, 180), "ok": func(p: Vector2) -> bool: return p.x >= 7.0},
			{"at": Vector2(1200, 180), "ok": func(p: Vector2) -> bool: return p.x <= 633.0},
			{"at": Vector2(320, 900), "ok": func(p: Vector2) -> bool: return p.y <= 377.0},
			{"at": Vector2(320, -500), "ok": func(p: Vector2) -> bool: return p.y >= 23.0},
		]
		for test: Dictionary in closed_cases:
			hero.global_position = test["at"]
			await get_tree().create_timer(0.15).timeout
			if not bool((test["ok"] as Callable).call(hero.global_position)):
				_fail("closed-room escape at %s" % hero.global_position)
				return
		# Leave the streamed body at the most adversarial corner.
		hero.global_position = Vector2(-500, -500)
		await get_tree().create_timer(0.4).timeout
		if hero.global_position.x < 7.0 or hero.global_position.y < 23.0:
			_fail("closed corner was not contained: %s" % hero.global_position)
			return
		_write_phase(1)

		if not await _wait_for(func() -> bool: return bool(dungeon.get("door_open")), 15.0):
			_fail("door never opened")
			return
		hero.global_position = Vector2(-500, -500)
		await get_tree().create_timer(0.5).timeout
		if int(dungeon.get("room_index")) != 1:
			_fail("wrong-corridor attempt advanced room")
			return
		if hero.global_position.x < 7.0 or hero.global_position.y < 23.0:
			_fail("open-door corner was not contained: %s" % hero.global_position)
			return
		_write_phase(2)
		# Let the host inspect the wrong-corridor state before attempting the
		# deliberate valid crossing.
		await get_tree().create_timer(1.2).timeout

		hero.global_position = Vector2(320, -500)
		if not await _wait_for(func() -> bool:
			return int(dungeon.get("room_index")) >= 2, 15.0):
			_fail("valid doorway crossing did not advance")
			return
		_write_phase(3)
		await get_tree().create_timer(1.0).timeout
		Net.leave()
		get_tree().quit(0)


	func _write_phase(phase: int) -> void:
		report["phase"] = phase
		var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
			file = null


	func _fail(message: String) -> void:
		report["error"] = message
		_write_phase(99)
		await get_tree().create_timer(1.0).timeout
		Net.leave()
		get_tree().quit(0)


	func _wait_for(condition: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(condition.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(condition.call())


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
