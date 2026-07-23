extends Node
## Pokémon world bring-up probe: Pikachu + Charmander in the PMD-composed
## dungeon — start room, combat room with the corrupt roster, Discharge /
## Fire Spin nova specials connecting, and all three rotation bosses
## (Latios -> Ho-Oh -> Mewtwo). Shots -> user://screenshots/pkmn_*.png.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/pkmn_%s.png" % t)
		print("SHOT ", t)

	func _reset_all() -> void:
		GameState.reset_campaign(); TimeManager.reset(7); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()

	func _run_hero(hero_id: String, wins: int, tag: String) -> void:
		_reset_all()
		GameState.meet_hero(hero_id)
		GameState.stats["expedition_wins_pokemon"] = wins
		print("BOSS_FOR_WORLD win%d = %s" % [wins, DungeonManager.boss_for_world("pokemon")])
		DungeonManager.plan_expedition("pokemon", hero_id, [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		_shot("%s_start" % tag)
		# combat room: enemies + roster art
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "combat":
				dun._enter_room(i); break
		await get_tree().create_timer(1.0).timeout
		_shot("%s_combat" % tag)
		# nova special: park an enemy next to the hero, fire, verify damage
		var target = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e): target = e; break
		if target != null:
			target.stun_time = 6.0
			target.global_position = Vector2(360, 240)
			hero.global_position = Vector2(330, 240)
			await get_tree().create_timer(0.2).timeout
			var hp0 = target.health.hp
			hero.meter = 100.0
			hero._do_special()
			await get_tree().create_timer(0.25).timeout
			_shot("%s_special" % tag)
			await get_tree().create_timer(0.6).timeout
			var hp1 = target.health.hp
			print("NOVA_HIT %s hp %d -> %d  (%s)" % [tag, hp0, hp1, "HIT" if hp1 < hp0 else "MISS"])
		# boss room
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.2).timeout
		_shot("%s_boss" % tag)

	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		await _run_hero("pikachu", 0, "pika_latios")
		await _run_hero("charmander", 1, "char_hooh")
		await _run_hero("pikachu", 2, "pika_mewtwo")
		print("PKMN_VERIFY_DONE")
		get_tree().quit()
