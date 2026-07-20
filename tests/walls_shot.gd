extends Node2D
## Windowed probe for the wall/obstacle prop overhaul: runs a dungeon in each
## prop world and screenshots the start room + first combat room.


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
	prober.set_script(preload("res://tests/walls_shot_stage.gd"))
	get_tree().root.add_child(prober)
	prober.call("next_world")
