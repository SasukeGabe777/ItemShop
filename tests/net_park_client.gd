extends Node
## Client half of tests/net_park_probe. Joins while the host is mid-dungeon:
## must get parked (overlay + signal), then receive the real welcome when the
## host returns to town, landing in town with a seat.


class Worker:
	extends Node

	const OUT_PATH := "user://net_park_client.json"

	var report: Dictionary = {
		"parked_fired": false, "park_reason": "", "landed_scene": "",
		"index": 0, "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.parked.connect(func(reason: String) -> void:
			report["parked_fired"] = true
			report["park_reason"] = reason)
		Net.join_failed.connect(func(reason: String) -> void:
			_finish("join failed: %s" % reason))
		Net.join_game("127.0.0.1", "ParkBro")

		var was_parked := await _wait_for(func() -> bool:
			return bool(report["parked_fired"]), 15.0)
		if not was_parked:
			_finish("never parked")
			return

		var landed := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return Net.my_index > 0 and scene != null \
				and scene.scene_file_path.ends_with("town.tscn"), 30.0)
		var scene := get_tree().current_scene
		report["landed_scene"] = scene.scene_file_path if scene != null else ""
		report["index"] = Net.my_index
		_finish("" if landed else "never landed in town after parking")


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
