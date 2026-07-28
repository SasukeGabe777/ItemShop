extends Node
## Windowed proof: daily alert, highlighted Gate Plaza target, run HUD, and
## doubled treasure-room chest spawns.

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
		BoomManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		BoomManager.force_expedition_boom("treasure_surge", "kingdom_hearts")
		DirAccess.make_dir_recursive_absolute("user://screenshots/")

		var briefing := DayBriefing.show_report(get_tree().current_scene)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/expedition_boom_briefing.png")
		briefing.queue_free()
		await get_tree().create_timer(0.25).timeout

		var gates := GatesPanel.new()
		get_tree().current_scene.add_child(gates)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/expedition_boom_gates.png")
		gates.queue_free()
		await get_tree().create_timer(0.25).timeout

		DungeonManager.plan_expedition("kingdom_hearts", "sora")
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.0).timeout
		var dungeon: Node = get_tree().current_scene
		var treasure_index := -1
		for index in range(dungeon.layout.size()):
			if String(dungeon.layout[index].get("kind", "")) == "treasure":
				treasure_index = index
				break
		if treasure_index >= 0:
			dungeon._enter_room(treasure_index)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/expedition_boom_dungeon.png")
		print("EXPEDITION_BOOM_CHESTS=", dungeon.room_root.get_children().filter(
			func(node: Node) -> bool: return node is Area2D).size())
		dungeon._enter_room(dungeon.layout.size() - 1)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/kh_first_full_boss.png")
		print("EXPEDITION_BOOM_SHOT_DONE")
		get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
