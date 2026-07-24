extends Node
## Client half of tests/net_disconnect_probe. Joins, follows into the dungeon,
## then quits abruptly — the host must clean up its hero and (since the host's
## own hero is parked dead in the probe) end the run.


class Worker:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "LeaverBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			get_tree().quit(0)
			return
		var in_dungeon := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 25.0)
		if in_dungeon:
			# linger so the host can observe our puppet and stage the run
			# (its own hero parked dead) before we drop
			await get_tree().create_timer(6.0).timeout
		# hard drop: close the peer and quit
		Net.leave()
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0)


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
