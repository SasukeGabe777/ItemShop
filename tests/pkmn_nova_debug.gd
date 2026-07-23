extends Node
## Headless logic probe: why does Charmander's Fire Spin nova miss a parked
## enemy that Pikachu's Discharge hits from identical range?

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _run(hero_id: String) -> void:
		GameState.reset_campaign(); TimeManager.reset(7); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.meet_hero(hero_id)
		DungeonManager.plan_expedition("pokemon", hero_id, [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.0).timeout
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "combat":
				dun._enter_room(i); break
		await get_tree().create_timer(0.8).timeout
		var target = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e): target = e; break
		if target == null:
			print("NO_TARGET"); return
		target.stun_time = 10.0
		target.global_position = Vector2(360, 240)
		hero.global_position = Vector2(330, 240)
		await get_tree().create_timer(0.2).timeout
		var sp: Dictionary = hero.combat_def().get("special", {})
		print("%s special kind=%s dmg=%s radius=%s cost=%s sheet_exists=%s" % [
			hero_id, sp.get("kind"), sp.get("dmg"), sp.get("radius"), sp.get("cost"),
			ResourceLoader.exists(String(sp.get("sheet", "")))])
		var hp0 = target.health.hp
		hero.meter = 100.0
		hero._do_special()
		await get_tree().process_frame
		for n in get_tree().current_scene.get_children():
			if n is Nova:
				print("  nova at %s, target at %s, dist %.1f, radius %.1f" % [
					n.global_position, target.global_position,
					n.global_position.distance_to(target.global_position), n.radius])
		await get_tree().create_timer(1.4).timeout
		print("  %s hp %d -> %d (%s)" % [hero_id, hp0, target.health.hp,
			"HIT" if target.health.hp < hp0 else "MISS"])

	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		await _run("pikachu")
		await _run("charmander")
		print("NOVA_DEBUG_DONE")
		get_tree().quit()
