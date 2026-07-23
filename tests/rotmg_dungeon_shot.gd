extends Node
## Probe: fresh state -> ROTMG dungeon with the Archer. Verifies the shooter
## basic attack (hold to auto-fire at the nearest enemy), the biome room floors,
## the enemy bullet swarm, the Archer's piercing special, and that Oryx is always
## the debut boss. Must run WINDOWED (screenshots need a real viewport).
class Probe:
	extends Node
	func _shot(name: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/%s.png" % name)

	func _ready() -> void:
		await get_tree().create_timer(1.0).timeout
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
		# Oryx must be the debut boss (wins == 0)
		var first_boss := DungeonManager.boss_for_world("rotmg")
		print("FIRST_BOSS=", first_boss, " (expect oryx)")
		GameState.meet_hero("archer")
		DungeonManager.plan_expedition("rotmg", "archer", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.2).timeout   # world-sized warmup
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		print("TRACK=", AudioManager.current_track)
		var dun: Node = get_tree().current_scene
		print("LAYOUT_KINDS=", dun.layout.map(func(r): return r.get("kind")))
		print("BOSS_ROOM_ENEMY=", dun.layout[dun.layout.size() - 1].get("enemies"))
		_shot("rotmg_start")
		# dismiss any pause layer just in case
		get_tree().paused = false

		# combat room: enemy swarm + hold-fire the ranged basic
		dun._enter_room(1)
		await get_tree().create_timer(1.0).timeout
		print("ENEMIES_IN_ROOM=", get_tree().get_nodes_in_group("enemies").size())
		_shot("rotmg_combat")
		# move RIGHT — hero should face right (facing-flip fix)
		Input.action_press("move_right")
		await get_tree().create_timer(0.4).timeout
		Input.action_release("move_right")
		_shot("rotmg_face_right")
		print("FACE_RIGHT flip_h=", dun.hero.visual.animated.flip_h)
		# move LEFT — hero should face left
		Input.action_press("move_left")
		await get_tree().create_timer(0.4).timeout
		Input.action_release("move_left")
		_shot("rotmg_face_left")
		print("FACE_LEFT flip_h=", dun.hero.visual.animated.flip_h)
		# hold fire — hero bullets (shot_flame VFX) + let enemies shoot back
		Input.action_press("attack")
		await get_tree().create_timer(1.2).timeout
		_shot("rotmg_fire")
		Input.action_release("attack")
		print("HERO_SHOTS=", dun.hero.get_meta("shots", 0),
			" HERO_FRAME_H=", dun.hero.visual.animated.sprite_frames.get_frame_texture("idle_down", 0).get_height())
		# archer piercing special
		dun.hero.meter = 100.0
		Input.action_press("special")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("special")
		await get_tree().create_timer(0.35).timeout
		_shot("rotmg_special")

		# boss room -> Oryx
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.0).timeout
		dun.hero.global_position = Vector2(320, 240)
		await get_tree().create_timer(0.5).timeout
		var bosses := get_tree().get_nodes_in_group("boss")
		print("BOSS_SPAWNED=", bosses.size(),
			" id=", (bosses[0].enemy_id if bosses.size() > 0 else "NONE"))
		_shot("rotmg_boss")
		print("ROTMG_DUNGEON_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
