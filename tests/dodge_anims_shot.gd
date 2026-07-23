extends Node
## Verify the dodge-animation drop (2026-07-22 round 2): Link somersault,
## Mario twirl, Luigi scramble, Pikachu + Charmander dashes — mid-roll
## screenshots per hero, plus a cooldown check (second dodge inside 0.3s
## must not dash).

const RUNS := [
	["zelda", "link"],
	["mario", "mario"],
	["mario", "luigi"],
	["pokemon", "pikachu"],
	["pokemon", "charmander"],
]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/dodge_%s.png" % t)
		print("SHOT ", t)

	func _reset() -> void:
		GameState.reset_campaign(); TimeManager.reset(2); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()

	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		for run in RUNS:
			_reset()
			GameState.meet_hero(run[1])
			DungeonManager.plan_expedition(run[0], run[1], [])
			SceneRouter.go("dungeon")
			await get_tree().create_timer(3.0).timeout
			var hero = get_tree().current_scene.hero
			hero.facing = Vector2(1, 0)
			var p0: Vector2 = hero.global_position
			hero._do_dodge(true)
			await get_tree().create_timer(0.1).timeout
			_shot("%s_roll" % run[1])
			# cooldown: immediate second dodge must not move the hero further
			await get_tree().create_timer(0.15).timeout
			var p1: Vector2 = hero.global_position
			hero._do_dodge(true)
			await get_tree().create_timer(0.2).timeout
			var moved: float = hero.global_position.distance_to(p1)
			print("DODGE %s dist %.0f cooldown_block=%s" % [run[1],
				p1.distance_to(p0), "OK" if moved < 8.0 else "FAIL(moved %.0f)" % moved])
		print("DODGE_VERIFY_DONE")
		get_tree().quit()
