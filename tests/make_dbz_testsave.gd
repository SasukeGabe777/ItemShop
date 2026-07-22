extends Node
## Builds a ready-to-play TEST SAVE in slot 2 that drops the player into the
## Dragon Ball chapter with resources to run one full loop
## (shop -> expedition -> Perfect Cell -> gate repair) WITHOUT grinding the
## campaign from chapter 1. Writes through the real managers + SaveManager so
## the result is a normal, menu-loadable save. Re-run any time to regenerate.
##
## Headless is fine (logic only, no rendering):
##   tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/make_dbz_testsave.tscn

func _ready() -> void:
	# fresh campaign state
	GameState.reset_campaign()
	TimeManager.reset(6)          # chapter 6 -> day 26, Morning
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()

	# make it obvious in the Continue / load menu
	GameState.game_title = "DBZ PLAYTEST - Ch.6 Dragon Ball"
	# both DBZ heroes already greeted (skips the hero-met cutscene on depart)
	GameState.meet_hero("goku")
	GameState.meet_hero("piccolo")
	# plenty for hire fees + the 400,000g gate repair at the end of the loop
	EconomyManager.gold = 500000

	# stock the shop: senzu beans to carry into the expedition, plus DBZ goods
	InventoryManager.add_item("senzu_bean", 10)
	for g in ["capsule", "scouter", "turtle_gi", "dragon_radar", "power_pole",
			"saiyan_armor", "dragon_ball", "nimbus_token"]:
		InventoryManager.add_item(g, 3)
	# put a few on the shop floor so the first sale needs no setup
	var i := 0
	for g in ["senzu_bean", "capsule", "scouter", "turtle_gi", "dragon_radar", "power_pole"]:
		InventoryManager.place_display(i, g)
		i += 1

	var ok := SaveManager.save_to_slot(2)
	print("SAVE ok=%s slot=2 chapter=%d day=%d gold=%d" % [
		ok, TimeManager.chapter, TimeManager.day, EconomyManager.gold])
	print("accessible_worlds=", BridgeManager.accessible_worlds())
	print("dbz_gate=", BridgeManager.gates.get("dragon_ball"))
	print("MAKE_DBZ_TESTSAVE_DONE")
	get_tree().quit()
