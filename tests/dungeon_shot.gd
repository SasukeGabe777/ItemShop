extends Node
## Probe: fresh state -> KH dungeon with Sora. Screenshots walking in two
## directions and mid-attack; verifies the dungeon music override resolves.
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
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
		GameState.meet_hero("sora")
		DungeonManager.plan_expedition("kingdom_hearts", "sora", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		print("TRACK=", AudioManager.current_track, " stream=", AudioManager.music_player.stream != null)
		Input.action_press("move_down")
		await get_tree().create_timer(0.45).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dungeon_down.png")
		Input.action_release("move_down")
		Input.action_press("move_left")
		Input.action_press("move_up")
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dungeon_diag.png")
		Input.action_release("move_left")
		Input.action_release("move_up")
		Input.action_press("move_right")
		await get_tree().create_timer(0.3).timeout
		Input.action_release("move_right")
		Input.action_press("attack")
		await get_tree().create_timer(0.12).timeout
		Input.action_release("attack")
		await get_tree().create_timer(0.08).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dungeon_attack.png")
		print("DUNGEON_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
