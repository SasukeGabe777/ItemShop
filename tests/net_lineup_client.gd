extends Node
## Client half of tests/net_lineup_probe. Follows the host into town, gets the
## lineup panel when the host opens the gates, picks its hero + belt, readies,
## and confirms it lands in the dungeon with its chosen hero.


class Worker:
	extends Node

	const OUT_PATH := "user://net_lineup_client.json"

	var report: Dictionary = {
		"joined": false, "lineup_seen": false, "in_dungeon": false,
		"my_hero": "", "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "LineupBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		var in_town := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("town.tscn"), 20.0)
		if not in_town:
			_finish("never followed into town")
			return
		var town := get_tree().current_scene

		# The host opens the gates -> a lineup panel appears on our machine.
		var panel_up := await _wait_for(func() -> bool:
			var lp: Variant = town.get("_lineup_panel")
			return lp != null and is_instance_valid(lp), 20.0)
		report["lineup_seen"] = panel_up
		if not panel_up:
			_finish("lineup panel never opened")
			return
		# Pick "link" and ready up (drive the request directly for determinism).
		await get_tree().create_timer(0.5).timeout
		Net.request("lineup.set", {"hero_id": "link", "consumables": []})

		var in_dungeon := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 25.0)
		report["in_dungeon"] = in_dungeon
		if in_dungeon:
			await get_tree().create_timer(1.0).timeout
			var d := get_tree().current_scene
			report["my_hero"] = String(d.get("hero").hero_id)
		_finish("" if in_dungeon else "never departed into the dungeon")


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
