extends Node
## Auto-plays a full dungeon offline, room by room: force-kills every enemy,
## walks the hero out the top door, and logs each room. Flags any room that
## fails to clear (door never opens with no enemies left) or fails to advance
## (door open, hero at the exit, but room_index never changes) — the
## "hard-stuck, no path to the next room" bug. Runs several expeditions to
## sample the randomised layout.


class Prober:
	extends Node

	var world_id := "naruto"
	var runs := 10
	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		for run in range(runs):
			await _play_once(run)
		if failures.is_empty():
			print("DUNGEON_AUTOPLAY_PROBE_PASS runs=%d" % runs)
			get_tree().quit(0)
		else:
			for f in failures:
				printerr("DUNGEON_AUTOPLAY_PROBE_FAIL: ", f)
			get_tree().quit(1)


	func _play_once(run: int) -> void:
		_reset()
		var hero_id := String(ContentDatabase.get_world(world_id).get("hero", "naruto"))
		DungeonManager.plan_expedition(world_id, hero_id, [], false)
		SceneRouter.go("dungeon")
		await get_tree().create_timer(1.5).timeout
		var d := get_tree().current_scene
		if d == null or not d.scene_file_path.ends_with("dungeon.tscn"):
			failures.append("run %d: never reached the dungeon" % run)
			return
		# log the whole layout composition for this run
		var layout: Array = d.get("layout")
		var comp: Array[String] = []
		for entry: Dictionary in layout:
			comp.append("%s[%d]" % [entry.get("kind"), (entry.get("enemies", []) as Array).size()])
		print("run %d layout: %s" % [run, " -> ".join(comp)])

		var last_room := -1
		var time_in_room := 0.0
		var visited: Array[int] = []
		while true:
			if bool(d.get("finished")):
				print("  run %d: cleared, reached %d rooms" % [run, visited.size()])
				break
			var ri := int(d.get("room_index"))
			if ri != last_room:
				last_room = ri
				time_in_room = 0.0
				visited.append(ri)
				var e: Dictionary = layout[ri]
				print("  run %d room %d: kind=%s enemies=%s" % [run, ri, e.get("kind"), e.get("enemies")])
			# force-kill every enemy in the room
			for node in get_tree().get_nodes_in_group("enemies"):
				var en := node as Node2D
				if en != null and is_instance_valid(en) and en.has_method("take_packet"):
					en.take_packet({"damage": 999999, "knockback": 0.0, "source": null},
						en.global_position)
			await get_tree().create_timer(0.25).timeout
			# once the door is open, stand on the exit to advance
			if bool(d.get("door_open")):
				var hero: Node2D = d.get("hero")
				if hero != null and is_instance_valid(hero):
					hero.global_position = Vector2(320, 14)
			await get_tree().create_timer(0.25).timeout
			time_in_room += 0.5
			if time_in_room > 6.0:
				var e2: Dictionary = layout[ri]
				var live := get_tree().get_nodes_in_group("enemies").size()
				failures.append("run %d STUCK at room %d (kind=%s enemies=%s): door_open=%s live_enemies=%d" % [
					run, ri, e2.get("kind"), e2.get("enemies"), str(d.get("door_open")), live])
				break
		# back to a clean scene before the next run
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await get_tree().create_timer(0.6).timeout


	func _reset() -> void:
		GameState.reset_campaign()
		GameState.campaign_active = true
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Prober.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
