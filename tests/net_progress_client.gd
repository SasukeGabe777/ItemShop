extends Node
## Client half of tests/net_progress_probe. Follows the host into the dungeon,
## waits for the party to advance past the empty start room, and reports the
## room it reached plus how many enemy puppets it can see there.


class Worker:
	extends Node

	const OUT_PATH := "user://net_progress_client.json"

	var report := {"joined": false, "in_dungeon": false, "reached_room": -1,
		"enemies_seen": 0, "error": ""}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "ProgressBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true
		var in_dungeon := await _wait_for(func() -> bool:
			var s := get_tree().current_scene
			return s != null and s.scene_file_path.ends_with("dungeon.tscn"), 30.0)
		report["in_dungeon"] = in_dungeon
		if not in_dungeon:
			_finish("never followed into the dungeon")
			return
		var d := get_tree().current_scene
		# wait for the host to advance the party past the start room
		var advanced := await _wait_for(func() -> bool:
			return int(d.get("room_index")) >= 1, 25.0)
		report["reached_room"] = int(d.get("room_index"))
		if advanced:
			await get_tree().create_timer(1.0).timeout
			report["enemies_seen"] = get_tree().get_nodes_in_group("enemies").size()
		# linger so the host can inspect our puppet/state
		_write()
		await get_tree().create_timer(4.0).timeout
		_finish("" if advanced else "party never advanced past the start room")


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _write() -> void:
		var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f = null


	func _finish(err: String) -> void:
		report["error"] = err
		_write()
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
