extends Node
## Client half of the full-run dungeon regression. The client, not the host,
## crosses every open north door so remote body streaming drives progression.


class Worker:
	extends Node

	const OUT_PATH := "user://net_dungeon_full_run_client.json"
	const RUN_COUNT := 3

	var report := {"runs": [], "error": ""}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "FullRunClient")
		if not await _wait_for(func() -> bool: return Net.my_index > 0, 10.0):
			_finish("no welcome within 10s")
			return

		for run_idx in RUN_COUNT:
			var arrived := await _wait_for(func() -> bool:
				var scene := get_tree().current_scene
				return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 25.0)
			if not arrived:
				_finish("run %d never followed into dungeon" % run_idx)
				return
			var dungeon := get_tree().current_scene
			var rooms: Array[int] = []
			var timed_out := false
			var started := Time.get_ticks_msec()
			var last_room := -1
			var room_seen_at := started
			while is_instance_valid(dungeon) and not bool(dungeon.get("finished")):
				var room := int(dungeon.get("room_index"))
				if rooms.is_empty() or rooms.back() != room:
					rooms.append(room)
				if room != last_room:
					last_room = room
					room_seen_at = Time.get_ticks_msec()
				# Briefly dwell so both peers can sample the cleared state and
				# blocker removal before this remote body advances the party.
				if bool(dungeon.get("door_open")) \
						and Time.get_ticks_msec() - room_seen_at >= 600:
					var hero: CombatHero = dungeon.get("hero")
					if hero != null and is_instance_valid(hero):
						hero.global_position = Vector2(320, 14)
				await get_tree().create_timer(0.05).timeout
				if Time.get_ticks_msec() - started > 60000:
					timed_out = true
					break
			if is_instance_valid(dungeon):
				var final_room := int(dungeon.get("room_index"))
				if rooms.is_empty() or rooms.back() != final_room:
					rooms.append(final_room)
			report["runs"].append({
				"rooms": rooms,
				"finished": is_instance_valid(dungeon) and bool(dungeon.get("finished")),
			})
			if timed_out:
				_finish("run %d timed out in rooms %s" % [run_idx, rooms])
				return
			if run_idx + 1 < RUN_COUNT:
				var left := await _wait_for(func() -> bool:
					var scene := get_tree().current_scene
					return scene == null or not scene.scene_file_path.ends_with("dungeon.tscn"),
					15.0)
				if not left:
					_finish("run %d never left dungeon" % run_idx)
					return

		_finish("")


	func _wait_for(condition: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(condition.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(condition.call())


	func _finish(error: String) -> void:
		report["error"] = error
		var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
			file = null
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
