extends Node
## Root-parented stage for blocker_shot: tours every built world's dungeon,
## screenshots the entry room and a deeper room (obstacles differ per room
## template), and quits.

const TOUR := [
	["kingdom_hearts", "sora"],
	["mario", "mario"],
	["final_fantasy", "cloud"],
	["zelda", "link"],
	["naruto", "naruto"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	for t in TOUR:
		var wid := String(t[0])
		var hid := String(t[1])
		GameState.reset_campaign()
		TimeManager.reset(4)
		EconomyManager.reset()
		InventoryManager.reset()
		BridgeManager.reset()
		StoryEventManager.reset()
		DungeonManager.reset()
		DungeonManager.plan_expedition(wid, hid, [], false)
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		var dungeon: Node = get_tree().get_first_node_in_group("dungeon_runtime")
		if dungeon == null:
			print("BLOCKER_SHOT no dungeon for ", wid)
			continue
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/blk_%s_room0.png" % wid)
		var layout: Array = dungeon.get("layout")
		dungeon.call("_enter_room", mini(2, layout.size() - 2))
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(
			"user://screenshots/blk_%s_room2.png" % wid)
		print("BLOCKER_SHOT done ", wid)
	print("BLOCKER_SHOT_DONE")
	get_tree().quit()
