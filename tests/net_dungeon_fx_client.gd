extends Node
## Client half of tests/net_dungeon_fx_probe: must SEE the host shooter's
## cosmetic bullets, replay its own swings to the host, and pull the whole
## party out with a retreat request.


class Worker:
	extends Node

	const OUT_PATH := "user://net_dungeon_fx_client.json"

	var report: Dictionary = {
		"joined": false, "eproj_seen": false, "finished_after_retreat": false,
		"boss_seen": false, "boss_visible": false,
		"error": "",
	}
	var _kinds_seen: Dictionary = {}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Replica.entity_spawned.connect(func(_eid: int, kind: String, node: Node) -> void:
			_kinds_seen[kind] = true
			if kind == "boss":
				report["boss_seen"] = true
				var visual: Variant = node.get("visual")
				report["boss_visible"] = node.is_visible_in_tree() \
					and visual != null and (visual as CanvasItem).visible)
		Net.join_game("127.0.0.1", "FxBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		var in_dungeon := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 30.0)
		if not in_dungeon:
			_finish("never followed into the dungeon")
			return
		var d := get_tree().current_scene
		await get_tree().create_timer(1.0).timeout

		# Park in the shooter's range; its bullets must replicate here.
		var hero: CombatHero = d.get("hero")
		hero.global_position = Vector2(400, 210)
		report["eproj_seen"] = await _wait_for(func() -> bool:
			return _kinds_seen.has("eproj"), 20.0)

		# Swing a few times so the host hears our action events.
		for i in 3:
			hero.facing = Vector2.LEFT
			hero._do_basic_attack()
			await get_tree().create_timer(0.5).timeout
		hero.meter = 999.0
		hero.facing = Vector2.RIGHT
		hero._do_special()
		await get_tree().create_timer(0.5).timeout

		# Retreat must end the run for everyone.
		Net.request("dungeon.retreat")
		report["finished_after_retreat"] = await _wait_for(func() -> bool:
			return bool(d.get("finished")), 15.0)
		await get_tree().create_timer(0.5).timeout
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
