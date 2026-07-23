extends Node
## Headless logic probe: the 0.3s dodge cooldown. If the second dodge fired,
## dodge_cooldown would RESET to ~0.46; if blocked it keeps ticking down.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign(); TimeManager.reset(2); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
		GameState.meet_hero("link")
		DungeonManager.plan_expedition("zelda", "link", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		var hero = get_tree().current_scene.hero
		hero.facing = Vector2(1, 0)
		hero._do_dodge(true)
		var cd0: float = hero.dodge_cooldown
		await get_tree().create_timer(0.25).timeout
		var cd1: float = hero.dodge_cooldown
		hero._do_dodge(true)
		var cd2: float = hero.dodge_cooldown
		print("COOLDOWN after_first=%.2f before_second=%.2f after_second=%.2f -> %s" % [
			cd0, cd1, cd2, "BLOCKED" if cd2 <= cd1 + 0.01 else "NOT BLOCKED"])
		await get_tree().create_timer(0.3).timeout
		hero._do_dodge(true)
		print("COOLDOWN expired redodge=%.2f -> %s" % [hero.dodge_cooldown,
			"FIRED" if hero.dodge_cooldown > 0.3 else "FAILED TO FIRE"])
		print("COOLDOWN_PROBE_DONE")
		get_tree().quit()
