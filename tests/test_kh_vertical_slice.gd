extends Node
## First Kingdom Hearts loop regression. The retired two-room test dungeon
## must never return: even legacy callers asking for it receive a full run.

var failures: Array[String] = []


func _ready() -> void:
	_reset_all()
	_test_first_shop_sale()
	_test_first_expedition_is_full()
	_test_save_roundtrip()
	if failures.is_empty():
		print("KH_FIRST_LOOP_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("KH_FIRST_LOOP_FAIL: " + message)


func _reset_all() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	BoomManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()
	var cfg: Dictionary = ContentDatabase.bal(
		"kingdom_hearts_vertical_slice", {})
	GameState.set_flag(String(cfg.get(
		"active_flag", "kh_vertical_slice_started")))
	CustomerGen.rng.seed = 20260727
	Negotiation.rng.seed = 20260727


func _test_first_shop_sale() -> void:
	var cfg: Dictionary = ContentDatabase.bal(
		"kingdom_hearts_vertical_slice", {})
	var customers := CustomerGen.generate_session_customers()
	_check(not customers.is_empty() and String(
		customers[0].get("id", "")) == String(cfg.get("customer_id", "")),
		"the guided first customer still leads the opening shop session")
	InventoryManager.place_display(0, "kh_potion")
	var negotiation := Negotiation.start(customers[0], "kh_potion")
	var outcome := negotiation.propose(1)
	negotiation.finalize_sale(outcome)
	_check(GameState.has_flag(String(cfg.get("starter_sale_flag", ""))),
		"the first guided sale completes its onboarding flag")
	var later_customers := CustomerGen.generate_session_customers()
	_check(later_customers.is_empty() or String(
		later_customers[0].get("id", "")) != String(cfg.get("customer_id", "")),
		"the guided customer is not forced forever")


func _test_first_expedition_is_full() -> void:
	# `true` deliberately exercises legacy saves/callers. It is ignored now.
	DungeonManager.plan_expedition(
		"kingdom_hearts", "sora", [], true)
	_check(not bool(DungeonManager.pending.get("vertical_slice", true)),
		"legacy short-run requests are retired")
	var layout := DungeonManager.generate_layout(
		"kingdom_hearts", 7, true)
	_check(layout.size() >= 5,
		"the first Kingdom Hearts expedition uses the full room count")
	_check(not layout.is_empty() and String(
		layout[-1].get("kind", "")) == "boss",
		"the first Kingdom Hearts expedition ends in a boss")
	_check(not layout.is_empty() and not (
		layout.size() == 2
		and String(layout[-1].get("kind", "")) == "combat"),
		"the obsolete two-room no-boss dungeon cannot return")


func _test_save_roundtrip() -> void:
	var saved := SaveManager._collect().duplicate(true)
	var starter_flag := String(ContentDatabase.bal(
		"kingdom_hearts_vertical_slice", {}).get(
			"starter_sale_flag", ""))
	GameState.flags.erase(starter_flag)
	SaveManager._apply(saved)
	_check(GameState.has_flag(starter_flag),
		"first-shop onboarding progress survives save/load")
