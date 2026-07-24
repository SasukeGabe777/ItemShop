extends Node
## Client half of tests/net_dungeon_probe. Follows the host into the dungeon
## with its own hero, swings at a host enemy (damage must land host-side and
## meter must tick here), gets mauled by a host chaser (damage applied HERE),
## walks out the door to advance the party, and sees the finish modal.


class Worker:
	extends Node

	const OUT_PATH := "user://net_dungeon_client.json"

	var report: Dictionary = {
		"joined": false, "in_dungeon": false, "my_hero": "", "host_puppet_hero": "",
		"layout_sig": "", "meter_after_hit": 0.0, "hp_after_touch": -1, "max_hp": 0,
		"room1": false, "finished_seen": false, "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "DungeonBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		var in_dungeon := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("dungeon.tscn"), 30.0)
		report["in_dungeon"] = in_dungeon
		if not in_dungeon:
			_finish("never followed into the dungeon")
			return
		var d := get_tree().current_scene
		await get_tree().create_timer(1.0).timeout
		report["my_hero"] = String(d.get("hero").hero_id)
		var pupped := await _wait_for(func() -> bool:
			return (d.get("_net_hero_puppets") as Dictionary).has(1), 10.0)
		if pupped:
			report["host_puppet_hero"] = String((d.get("_net_hero_puppets") as Dictionary)[1].hero_id)
		report["layout_sig"] = _layout_sig(d.get("layout"))

		# 1. Our swing on the host's parked test enemy (puppet here).
		var target := await _wait_for_enemy_near(Vector2(300, 200), 20.0)
		if target == null:
			_finish("test enemy puppet never appeared")
			return
		var hero: CombatHero = d.get("hero")
		hero.global_position = Vector2(276, 200)
		hero.facing = Vector2.RIGHT
		await get_tree().create_timer(0.4).timeout
		hero._do_basic_attack()
		await get_tree().create_timer(0.8).timeout
		report["meter_after_hit"] = hero.meter

		# 2. The host's chaser must hurt US (applied on this machine).
		hero.global_position = Vector2(430, 220)
		var hurt := await _wait_for(func() -> bool:
			return hero.health.hp < hero.health.max_hp, 25.0)
		report["hp_after_touch"] = hero.health.hp
		report["max_hp"] = hero.health.max_hp
		if not hurt:
			_finish("never took forwarded damage")
			return

		# 3. Walk out the top door: the host must advance the whole party.
		hero.global_position = Vector2(320, 20)
		var advanced := await _wait_for(func() -> bool:
			return int(d.get("room_index")) == 1, 20.0)
		report["room1"] = advanced

		# 4. The host ends the expedition; we get the modal + finished flag.
		var fin := await _wait_for(func() -> bool: return bool(d.get("finished")), 25.0)
		report["finished_seen"] = fin
		await get_tree().create_timer(1.0).timeout
		_finish("")


	func _wait_for_enemy_near(at: Vector2, timeout: float) -> Node2D:
		var waited := 0.0
		while waited < timeout:
			for node in get_tree().get_nodes_in_group("enemies"):
				var e := node as Node2D
				if e != null and is_instance_valid(e) and e.global_position.distance_to(at) < 24.0:
					return e
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return null


	static func _layout_sig(layout: Array) -> String:
		var parts: Array[String] = []
		for entry: Dictionary in layout:
			parts.append("%s:%s" % [entry.get("kind"), str(entry.get("enemies"))])
		return "%d|%s" % [layout.size(), "|".join(parts)]


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
