extends Node
## Verify: beam now connects with enemies (was passing through), clean DBZ HUD
## (HP + boss bars), and whole-tile rock barriers. Shots -> user://screenshots/.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbzv_%s.png" % t)
		print("SHOT ", t)
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign(); TimeManager.reset(6); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.meet_hero("piccolo")
		DungeonManager.plan_expedition("dragon_ball", "piccolo", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		# combat room with an enemy
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "combat":
				dun._enter_room(i); break
		await get_tree().create_timer(1.0).timeout
		_shot("rocks")   # HP bar visible + rock barriers
		# BEAM-HIT: park an enemy, stand to its left, fire SBC through it
		var target = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e): target = e; break
		if target != null:
			target.stun_time = 6.0
			target.global_position = Vector2(420, 240)
			hero.global_position = Vector2(300, 240)
			Input.action_press("move_right"); await get_tree().create_timer(0.12).timeout
			Input.action_release("move_right"); await get_tree().create_timer(0.2).timeout
			var hp0 = target.health.hp
			hero.meter = 100.0
			Input.action_press("special"); await get_tree().create_timer(0.05).timeout
			Input.action_release("special"); await get_tree().create_timer(0.25).timeout
			_shot("beam")
			await get_tree().create_timer(0.4).timeout
			var hp1 = target.health.hp
			print("BEAM_HIT hp %d -> %d  (%s)" % [hp0, hp1, "HIT" if hp1 < hp0 else "MISS"])
		# boss room -> boss bar
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.0).timeout
		if dun.boss_bar != null:
			dun.boss_bar.visible = true; dun.boss_bar.max_value = 100; dun.boss_bar.value = 68
		await get_tree().create_timer(0.3).timeout
		_shot("boss")
		print("DBZ_VERIFY_DONE")
		get_tree().quit()
