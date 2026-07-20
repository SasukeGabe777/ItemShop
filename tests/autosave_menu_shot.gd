extends Node2D
## Probe: the Continue menu shows the per-portion autosave as a loadable entry.
## Seeds an Evening slot save and a Night autosave, then hands off to a
## root-parented stage 2 (SceneRouter.go frees this node — AGENT_GUIDE §3).


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	GameState.campaign_active = true
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	TimeManager.advance(2)
	EconomyManager.add_gold(750)
	SaveManager.save_to_slot(1)
	TimeManager.advance(1)
	print("MENU autosave summary: ", SaveManager.autosave_summary())
	print("MENU slot 1 summary: ", SaveManager.slot_summary(1))
	var prober := Node.new()
	prober.set_script(preload("res://tests/autosave_menu_shot_stage.gd"))
	get_tree().root.add_child(prober)
	SceneRouter.go("main_menu")
