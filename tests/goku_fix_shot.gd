extends Node
## Verify round-2 DBZ fixes: eyes-open idle, fly facing the right way (was
## mirrored/backwards), and the enemy hurtbox now matching the sprite body.
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
		await get_tree().create_timer(3.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var hero = get_tree().current_scene.hero
		# IDLE facing down, standing still — eyes should be open
		hero.visual.face(Vector2.DOWN, false)
		hero.visual.play_action("idle", Vector2.DOWN)
		await get_tree().create_timer(0.5).timeout
		_shot("idle"); print("IDLE_ANIM=", hero.visual.animated.animation)
		# FLY poses shown statically (no dash off the cliff): right then left
		hero.visual.play_action("fly", Vector2.RIGHT)
		await get_tree().create_timer(0.2).timeout
		_shot("flyR"); print("FLYR flip_h=", hero.visual.animated.flip_h)
		hero.visual.play_action("fly", Vector2.LEFT)
		await get_tree().create_timer(0.2).timeout
		_shot("flyL"); print("FLYL flip_h=", hero.visual.animated.flip_h)
		# ENEMY HURTBOX check — instantiate the dino and report its hurtbox vs body
		var e = Enemy.new()
		get_tree().current_scene.add_child(e)
		e.setup("dbz_dinosaur", hero)
		await get_tree().create_timer(0.2).timeout
		var hb := e.hurtbox.get_child(0) as CollisionShape2D
		var sz = hb.shape.size if hb.shape is RectangleShape2D else Vector2(-1, -1)
		print("DINO hurtbox_kind=", hb.shape.get_class(), " size=", sz, " hit_radius=", e.hit_radius)
		print("GOKU_FIX2_DONE")
		get_tree().quit()
