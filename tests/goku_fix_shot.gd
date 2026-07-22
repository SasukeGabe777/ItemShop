extends Node
## Windowed verification of the DBZ combat-feedback fixes with Goku.
## beam/fly are captured in the enemy-free START room so Goku stands still and
## stays framed; the combat room (barriers) + melee were confirmed separately.
## Shots -> user://screenshots/goku_fix_*.png. Run WINDOWED.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/goku_fix_%s.png" % t)
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
		await get_tree().create_timer(2.2).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var hero = get_tree().current_scene.hero
		# face right, hold still (start room has no enemies)
		Input.action_press("move_right"); await get_tree().create_timer(0.15).timeout
		Input.action_release("move_right"); await get_tree().create_timer(0.4).timeout
		# MELEE (clean punch, verify no stray bar)
		Input.action_press("attack"); await get_tree().create_timer(0.08).timeout
		Input.action_release("attack"); await get_tree().create_timer(0.05).timeout
		_shot("melee2")
		await get_tree().create_timer(0.5).timeout
		# BEAM — capture mid-grow to read the origin height
		hero.meter = 100.0
		Input.action_press("special"); await get_tree().create_timer(0.03).timeout
		Input.action_release("special"); await get_tree().create_timer(0.20).timeout
		_shot("beam")
		print("BEAM done, hero_y=", hero.global_position.y)
		await get_tree().create_timer(0.7).timeout
		# FLY dodge — capture the fly pose
		Input.action_press("move_right"); await get_tree().create_timer(0.05).timeout
		Input.action_press("dodge"); await get_tree().create_timer(0.09).timeout
		_shot("fly")
		print("FLY_ANIM=", hero.visual.animated.animation if hero.visual and hero.visual.animated else "?")
		Input.action_release("dodge"); Input.action_release("move_right")
		print("GOKU_FIX_SHOT_DONE")
		get_tree().quit()
