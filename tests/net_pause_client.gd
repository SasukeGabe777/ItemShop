extends Node
## Client half of tests/net_pause_probe: host pause must pause this client;
## this client's own pause request must do nothing (its menus float over a
## running world instead).


class Worker:
	extends Node

	const OUT_PATH := "user://net_pause_client.json"

	var report: Dictionary = {
		"joined": false, "paused_with_host": false, "unpaused_with_host": false,
		"own_pause_ignored": false, "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "PauseBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		# Host pauses shortly after seating us.
		report["paused_with_host"] = await _wait_for(func() -> bool:
			return get_tree().paused, 10.0)
		report["unpaused_with_host"] = await _wait_for(func() -> bool:
			return not get_tree().paused, 10.0)

		# Our own pause request must not pause anything.
		Net.request_tree_pause(true)
		await get_tree().create_timer(1.0).timeout
		report["own_pause_ignored"] = not get_tree().paused
		_finish("")


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _finish(err: String) -> void:
		report["error"] = err
		var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f = null
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
