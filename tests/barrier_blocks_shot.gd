extends Node2D
## Windowed launcher for the five supplied world-specific barrier blocks.


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	TimeManager.reset(6)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	DungeonManager.reset()
	var prober := Node.new()
	prober.set_script(preload("res://tests/barrier_blocks_shot_stage.gd"))
	get_tree().root.add_child(prober)
	prober.call("next_world")
