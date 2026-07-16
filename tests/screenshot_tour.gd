extends Node
## Windowed smoke test: boots a fresh campaign and screenshots the main scenes
## into user://screenshots/. Run: godot --path . res://tests/screenshot_tour.tscn
## A runner node is parked on the root so it survives scene changes.


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	EconomyManager.add_gold(5000)
	for id in ["kingdom_key", "sea_salt_ice_cream", "super_mushroom", "buster_sword", "paopu_fruit", "kh_potion", "gummi_block", "blaze_shard"]:
		InventoryManager.add_item(id, 2)
	var i := 0
	for id in ["kingdom_key", "sea_salt_ice_cream", "super_mushroom", "buster_sword", "paopu_fruit", "kh_potion"]:
		InventoryManager.place_display(i, id)
		i += 1
	StoryEventManager.queue.append("intro")
	var runner := TourRunner.new()
	get_tree().root.add_child.call_deferred(runner)


class TourRunner:
	extends Node
	var step: int = 0
	var wait: float = 1.6

	func _ready() -> void:
		get_tree().change_scene_to_file("res://scenes/story/story_player.tscn")

	func _process(delta: float) -> void:
		wait -= delta
		if wait > 0.0:
			return
		wait = 1.6
		step += 1
		match step:
			1:
				_shot("story")
				get_tree().change_scene_to_file("res://scenes/town/town.tscn")
			2:
				_shot("town")
				get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
			3:
				_shot("shop")
				DungeonManager.plan_expedition("kingdom_hearts", "sora", ["kh_potion"])
				get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")
			4:
				_shot("dungeon")
				get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
			5:
				_shot("main_menu")
				print("SCREENSHOT_TOUR_DONE: " + ProjectSettings.globalize_path("user://screenshots/"))
				get_tree().quit()

	func _shot(tag: String) -> void:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://screenshots/%s.png" % tag)
		print("shot: " + tag)
