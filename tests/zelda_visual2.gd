extends Node2D
## Windowed in-dungeon visual probe: real Hyrule run as Link — swings, bomb,
## then jumps to the boss room for screenshots of the boss as the player sees it.


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	TimeManager.reset(4)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	DungeonManager.reset()
	var prober := Node.new()
	prober.set_script(preload("res://tests/zelda_visual2_stage.gd"))
	get_tree().root.add_child(prober)
	DungeonManager.plan_expedition("zelda", "link", [], false)
	SceneRouter.go("dungeon")
