extends Node
## Verify round 3: Sora rebuilt (walk sides, keyblade melee, Strike Raid,
## preserved roll), Naruto side walk no longer spins.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/r3_%s.png" % t)
		print("SHOT ", t)
	func _reset() -> void:
		GameState.reset_campaign(); TimeManager.reset(1); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		_reset()
		GameState.meet_hero("sora")
		DungeonManager.plan_expedition("kingdom_hearts", "sora", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		var hero = get_tree().current_scene.hero
		hero.facing = Vector2(1, 0)
		Input.action_press("move_right"); await get_tree().create_timer(0.3).timeout
		Input.action_release("move_right")
		_shot("sora_walk_side")
		hero._do_basic_attack(); await get_tree().create_timer(0.15).timeout
		_shot("sora_melee")
		hero.meter = 100.0; hero._do_special(); await get_tree().create_timer(0.2).timeout
		_shot("sora_strike_raid")
		await get_tree().create_timer(0.6).timeout
		hero._do_dodge(true); await get_tree().create_timer(0.12).timeout
		_shot("sora_roll")
		_reset()
		GameState.meet_hero("naruto")
		DungeonManager.plan_expedition("naruto", "naruto", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		hero = get_tree().current_scene.hero
		hero.facing = Vector2(1, 0)
		Input.action_press("move_right"); await get_tree().create_timer(0.3).timeout
		Input.action_release("move_right")
		_shot("naruto_walk_side")
		print("R3_VERIFY_DONE")
		get_tree().quit()
