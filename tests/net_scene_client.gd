extends Node
## Client half of tests/net_scene_follow_probe. Two-stage: the worker lives on
## the tree ROOT so host-ordered scene changes cannot free it. Records every
## scene it lands in until it reaches the shop.


class Worker:
	extends Node

	const OUT_PATH := "user://net_scene_client.json"

	var report: Dictionary = {"joined": false, "saw": [], "error": ""}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_failed.connect(func(reason: String) -> void:
			_finish("join failed: %s" % reason))
		var err := Net.join_game("127.0.0.1", "SceneBro")
		if err != OK:
			_finish("create_client returned %s" % error_string(err))
			return
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true
		var deadline := 25.0
		while deadline > 0.0:
			var scene := get_tree().current_scene
			var path := scene.scene_file_path if scene != null else ""
			var saw: Array = report["saw"]
			if path != "" and (saw.is_empty() or String(saw[-1]) != path):
				saw.append(path)
			if path.ends_with("shop.tscn"):
				break
			await get_tree().create_timer(0.2).timeout
			deadline -= 0.2
		_finish("" if deadline > 0.0 else "never reached the shop")


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
