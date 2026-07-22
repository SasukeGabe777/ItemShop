extends Node
## Verify the DBZ HUD skin: green HP bar in a black frame, red boss bar in a
## black frame. Shots -> user://screenshots/dbz_hud_*.png. Run WINDOWED.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		# crop the top HUD strip (0,0 .. width x 60) for a close look, plus full
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://screenshots/dbz_hud_%s.png" % t)
		var strip := img.get_region(Rect2i(0, 0, img.get_width(), 64))
		strip.save_png("user://screenshots/dbz_hud_%s_strip.png" % t)
		print("SHOT ", t)
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign(); TimeManager.reset(6); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.meet_hero("goku")
		DungeonManager.plan_expedition("dragon_ball", "goku", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		# damage the hero a bit so the HP bar shows a partial green fill
		hero.health.hp = int(hero.health.max_hp * 0.6)
		hero.hp_changed.emit(hero.health.hp, hero.health.max_hp)
		await get_tree().create_timer(0.4).timeout
		_shot("hp")
		# boss room -> boss bar
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.0).timeout
		if dun.boss_bar != null:
			dun.boss_bar.visible = true
			dun.boss_bar.max_value = 100; dun.boss_bar.value = 72
		await get_tree().create_timer(0.4).timeout
		_shot("boss")
		print("DBZ_HUD_SHOT_DONE")
		get_tree().quit()
