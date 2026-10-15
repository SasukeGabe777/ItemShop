extends Node
## Drives real menu buttons through a failed departure and retry, then checks
## the finished run banks deferred floor loot once and locks hero controls.

class Probe:
	extends Node

	var failures: Array[String] = []

	func _ready() -> void:
		await get_tree().create_timer(0.5).timeout
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		InventoryManager.storage = {"kh_potion": 1}
		RelationshipManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.meet_hero("sora")
		DayBriefing.last_shown_day = TimeManager.day
		EconomyManager.gold = 0
		_check(Net.host_game("RetryHost") == OK, "could not host isolated session")
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		Net.request("lineup.begin", {"world_id": "kingdom_hearts"})
		await get_tree().process_frame
		var town := get_tree().current_scene
		var panel: LineupPanel = town.get("_lineup_panel")
		_check(is_instance_valid(panel), "lineup never opened")
		if not is_instance_valid(panel):
			_finish()
			return
		_button(panel, "Add").pressed.emit()
		_button(panel, "Add").pressed.emit()
		_check(panel._chosen == ["kh_potion"], "belt accepted more copies than storage owns")
		_check("stock" in panel._status.text, "stock rejection was not explained")
		var ready := _button(panel, "Ready")
		ready.pressed.emit()
		await get_tree().process_frame
		_check(not ready.disabled, "Ready remained disabled after insufficient-gold rejection")
		for control: BaseButton in panel._editing_controls:
			_check(not control.disabled, "a lineup editor remained disabled after rejection")
		_check("gold" in panel._status.text, "departure rejection was not explained")
		await _shot("lineup_retry.png")
		EconomyManager.gold = 10000
		ready.pressed.emit()
		await get_tree().create_timer(1.5).timeout
		var dungeon := get_tree().current_scene
		_check(dungeon.scene_file_path.ends_with("dungeon.tscn"), "retry did not depart")
		if not dungeon.scene_file_path.ends_with("dungeon.tscn"):
			_finish()
			return
		var hero: CombatHero = dungeon.get("hero")
		var root: Node = dungeon.get("room_root")
		var before_items := InventoryManager.count("kh_potion")
		var before_gold := EconomyManager.gold
		var first := LootPickup.new()
		first.setup_item("kh_potion")
		root.add_child(first)
		first._collect()
		first._collect() # same-frame duplicate overlaps must not count twice
		var late := LootPickup.new()
		late.setup_item("kh_potion")
		var coins := LootPickup.new()
		coins.setup_gold(77)
		var results: Array[Dictionary] = []
		DungeonManager.expedition_finished.connect(func(result: Dictionary) -> void:
			results.append(result))
		dungeon.call("_finish", true, false)
		# Mirrors Enemy._on_died: killed emits before deferred drops are inserted.
		root.call_deferred("add_child", late)
		root.call_deferred("add_child", coins)
		await get_tree().create_timer(0.25).timeout
		_check(results.size() == 1, "expedition did not settle exactly once")
		if not results.is_empty():
			_check(int(results[0]["loot"].get("kh_potion", 0)) == 2,
				"result missed deferred loot or counted a pickup twice")
		_check(InventoryManager.count("kh_potion") == before_items + 2,
			"earned floor loot was not banked")
		_check(EconomyManager.gold == before_gold + 77, "loose floor gold was not banked")
		var position := hero.global_position
		Input.action_press("move_right")
		Input.action_press("attack")
		await get_tree().create_timer(0.25).timeout
		Input.action_release("move_right")
		Input.action_release("attack")
		_check(hero.global_position.is_equal_approx(position) and not hero.can_process(),
			"hero remained controllable behind expedition results")
		await _shot("settled_expedition.png")
		_finish()

	func _button(root: Node, prefix: String) -> Button:
		for node: Node in root.find_children("*", "Button", true, false):
			if (node as Button).text.begins_with(prefix):
				return node as Button
		return null

	func _shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots/recovery/")
		get_viewport().get_texture().get_image().save_png("user://screenshots/recovery/" + name)

	func _check(ok: bool, message: String) -> void:
		if not ok:
			failures.append(message)

	func _finish() -> void:
		Net.leave()
		if failures.is_empty():
			print("EXPEDITION_RECOVERY_PROBE_PASS")
		else:
			for message: String in failures:
				printerr("EXPEDITION_RECOVERY_PROBE_FAIL: " + message)
		get_tree().quit(0 if failures.is_empty() else 1)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
