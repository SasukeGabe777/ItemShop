extends Node
func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/subdbg_%s.png" % t)
		print("SHOT ", t)
	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		GameState.reset_campaign(); TimeManager.reset(1); EconomyManager.reset()
		MarketManager.reset(); EconomyManager.reset(); InventoryManager.reset()
		RelationshipManager.reset(); BridgeManager.reset(); DungeonManager.reset()
		StoryEventManager.reset(); ShopFurnitureManager.reset()
		GameState.meet_hero("naruto")
		DungeonManager.plan_expedition("naruto", "naruto", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var dun = get_tree().current_scene
		var hero = dun.hero
		hero.facing = Vector2(1, 0)
		print("HERO at ", hero.global_position)
		hero._do_dodge(true)
		await get_tree().create_timer(0.08).timeout
		for c in dun.get_children():
			if c is EffectFlipbook:
				print("FLIPBOOK at ", c.global_position, " frame ", c._sprite.frame, " visible ", c.visible, " tex ", c._sprite.texture != null)
		_shot("early")
		await get_tree().create_timer(0.2).timeout
		_shot("mid")
		print("SUBDBG_DONE")
		get_tree().quit()
