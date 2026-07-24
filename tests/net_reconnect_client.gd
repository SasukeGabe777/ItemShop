extends Node
## Client half of tests/net_reconnect_probe. Joins, gets kicked by the host
## (simulated Wi-Fi drop), and must auto-reconnect into the SAME seat with
## the same session token.


class Worker:
	extends Node

	const OUT_PATH := "user://net_reconnect_client.json"

	var report: Dictionary = {
		"joined": false, "index_before": 0, "lost_fired": false,
		"reconnected_fired": false, "index_after": 0, "token_same": false,
		"error": "",
	}
	var _token_before := ""


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.connection_lost.connect(func() -> void: report["lost_fired"] = true)
		Net.reconnected.connect(func() -> void: report["reconnected_fired"] = true)
		Net.join_game("127.0.0.1", "DropBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true
		report["index_before"] = Net.my_index
		_token_before = Net.session_token

		# The host kicks us shortly; wait for the full drop->reconnect cycle.
		var recon := await _wait_for(func() -> bool:
			return bool(report["reconnected_fired"]), 40.0)
		report["index_after"] = Net.my_index
		report["token_same"] = Net.session_token == _token_before
		if recon:
			# linger so the host probe can observe the reconnected seat before
			# our quit disconnects it again
			await get_tree().create_timer(5.0).timeout
		_finish("" if recon else "never reconnected")


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
