extends Node
## Capture consecutive frames of Luigi and Naruto walking to diagnose the
## reported moonwalk/spin from actual motion, not stills.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _reset() -> void:
		GameState.reset_campaign(); TimeManager.reset(1); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
	func _run(world: String, hero_id: String, dirn: String, action: String, n: int) -> void:
		_reset()
		GameState.meet_hero(hero_id)
		DungeonManager.plan_expedition(world, hero_id, [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		# clear the spawn surroundings first so the camera can center
		Input.action_press("move_down")
		await get_tree().create_timer(0.5).timeout
		Input.action_release("move_down")
		Input.action_press(action)
		await get_tree().create_timer(0.3).timeout
		for i in range(n):
			get_viewport().get_texture().get_image().save_png(
				"user://screenshots/wc_%s_%s_%02d.png" % [hero_id, dirn, i])
			await get_tree().create_timer(0.08).timeout
		Input.action_release(action)
		print("CAPTURED ", hero_id, " ", dirn)
	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		await _run("mario", "luigi", "right", "move_right", 8)
		await _run("mario", "mario", "right", "move_right", 8)
		await _run("naruto", "naruto", "right", "move_right", 8)
		print("WC_DONE")
		get_tree().quit()
