extends Node
## Verify the 2026-07-22 playtest-fix round: Mario's rebuilt anims (walk sides,
## hammer, fireball), Pokémon FRLG rooms + obstacle props + boulder barriers,
## Charmander true side walk, capped boss size in a real boss room.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/fix_%s.png" % t)
		print("SHOT ", t)

	func _reset() -> void:
		GameState.reset_campaign(); TimeManager.reset(2); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()

	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		# --- Mario: walk side + hammer + fireball ---
		_reset()
		GameState.meet_hero("mario")
		DungeonManager.plan_expedition("mario", "mario", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		hero.facing = Vector2(1, 0)
		Input.action_press("move_right")
		await get_tree().create_timer(0.35).timeout
		Input.action_release("move_right")
		_shot("mario_walk_side")
		hero._do_basic_attack()
		await get_tree().create_timer(0.15).timeout
		_shot("mario_hammer")
		hero.meter = 100.0
		hero._do_special()
		await get_tree().create_timer(0.2).timeout
		_shot("mario_special")
		# --- Pokémon: rooms, props, barriers, charmander side, capped boss ---
		_reset()
		GameState.meet_hero("charmander")
		GameState.stats["expedition_wins_pokemon"] = 2
		DungeonManager.plan_expedition("pokemon", "charmander", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		dun = get_tree().current_scene
		hero = dun.hero
		_shot("pkmn_start_pallet")
		var combats: Array = []
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "combat":
				combats.append(i)
		for n in range(mini(3, combats.size())):
			dun._enter_room(combats[n])
			await get_tree().create_timer(0.9).timeout
			hero.facing = Vector2(1, 0)
			Input.action_press("move_right")
			await get_tree().create_timer(0.25).timeout
			Input.action_release("move_right")
			_shot("pkmn_combat_%d" % n)
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.2).timeout
		_shot("pkmn_boss_capped")
		print("FIXES_VERIFY_DONE")
		get_tree().quit()
