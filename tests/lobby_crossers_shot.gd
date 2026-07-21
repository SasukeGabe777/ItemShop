extends Node
## Probe: watch ambient travellers fade into the Crossroads plaza (with a
## speech bubble) and confirm the shared white, centered name tag on both a
## crosser and a real shop customer. Windowed only (screenshots).
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var town: Node = get_tree().current_scene
		town.player.position = Vector2(360, 350)

		var lc: LobbyCrossers = null
		for ch in town.get_children():
			if ch is LobbyCrossers:
				lc = ch
				break
		if lc == null:
			print("LOBBY_SHOT_FAIL: no LobbyCrossers in town")
			get_tree().quit()
			return

		# force three travellers, place them in frame, then freeze the manager
		# so nothing else spawns/moves and the shot stays readable
		while lc._crossers.size() < 3:
			lc._spawn()
		var xs := [200, 320, 440]
		for i in range(3):
			(lc._crossers[i]["node"] as Node2D).position = Vector2(xs[i], 350)
		lc._say(lc._crossers[1]["node"], lc._crossers[1]["visual"], "So this is the Crossroads...")
		lc.set_process(false)
		for c in lc._crossers:
			print("CROSSER name=", _tag_of(c["node"]), " scale=", (c["visual"] as CharacterVisual).scale.y)

		# a real shop customer (stable pool character, NOT the under-rework Sora)
		var sc := ShopCustomer.new()
		town.add_child(sc)
		sc.setup({"name": "Krillin", "world": "dragon_ball", "hero_ref": "",
			"id": "krillin_cust", "archetype": "adventurer", "named": true,
			"color": "#e8b070"}, [Vector2(560, 350)], Vector2(560, 560))
		sc.position = Vector2(560, 350)
		sc._paused_for_negotiation = true

		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/lobby_crossers_1.png")
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/lobby_crossers_2.png")
		print("LOBBY_SHOT_DONE")
		get_tree().quit()

	func _tag_of(node: Node) -> String:
		for ch in node.get_children():
			if ch is Label:
				return (ch as Label).text
		return "(none)"

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
