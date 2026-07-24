extends Node
## Client half of tests/net_join_late_probe. Joins a host that is ALREADY
## mid-campaign in the shop; must land in the shop with the host's state.


class Worker:
	extends Node

	const OUT_PATH := "user://net_late_client.json"

	var report: Dictionary = {
		"joined": false, "scene": "", "gold": -1, "day": -1, "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_failed.connect(func(reason: String) -> void:
			_finish("join failed: %s" % reason))
		var err := Net.join_game("127.0.0.1", "LateBro")
		if err != OK:
			_finish("create_client returned %s" % error_string(err))
			return
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true
		var landed := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("shop.tscn"), 15.0)
		var scene := get_tree().current_scene
		report["scene"] = scene.scene_file_path if scene != null else ""
		report["gold"] = EconomyManager.gold
		report["day"] = TimeManager.day
		_finish("" if landed else "never landed in the shop")


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
