extends Node
## Expedition Boom and chapter-safe order regression proof.

var failures: Array[String] = []


func _ready() -> void:
	_reset_all()
	_validate_expedition_booms()
	_test_unlocked_world_targeting()
	_test_run_context_and_save()
	_test_order_access()
	if failures.is_empty():
		print("EXPEDITION_BOOM_TEST_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("EXPEDITION_BOOM_TEST_FAIL: " + message)


func _reset_all() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	RelationshipManager.reset()
	ShopFurnitureManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	BoomManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	BoomManager.rng.seed = 20260727
	BoomManager.expedition_rng.seed = 20260727
	CustomerGen.rng.seed = 20260727


func _validate_expedition_booms() -> void:
	_check(ContentDatabase.expedition_booms.size() >= 2,
		"multiple Expedition Booms are data-defined")
	for boom_id: String in ContentDatabase.expedition_booms:
		var definition: Dictionary = ContentDatabase.expedition_booms[boom_id]
		_check(String(definition.get("effect", "")) in ["drop_rate", "chest_spawn"],
			"%s has a supported dungeon effect" % boom_id)
		_check(float(definition.get("multiplier", 0.0)) > 1.0,
			"%s has a meaningful multiplier" % boom_id)
		_check("{world_name}" in String(definition.get("announcement", "")),
			"%s announces its selected world" % boom_id)


func _test_unlocked_world_targeting() -> void:
	_check(BridgeManager.accessible_worlds() == ["kingdom_hearts"],
		"chapter one exposes only Kingdom Hearts")
	_check(not BoomManager.force_expedition_boom("loot_frenzy", "mario"),
		"a locked world's Expedition Boom is rejected")
	for roll_index in range(30):
		BoomManager.clear_expedition_boom(false)
		BoomManager._roll_daily_expedition_boom(true)
		_check(BoomManager.expedition_world_id == "kingdom_hearts",
			"daily roll %d targets an unlocked world" % roll_index)
	_check("Kingdom Hearts" in BoomManager.expedition_announcement(),
		"announcement names the selected unlocked world")


func _test_run_context_and_save() -> void:
	_check(BoomManager.force_expedition_boom("loot_frenzy", "kingdom_hearts"),
		"loot frenzy can target the unlocked expedition")
	DungeonManager.plan_expedition("kingdom_hearts", "sora")
	_check(DungeonManager.pending_expedition_multiplier("drop_rate") == 4.0,
		"4x drop rate is snapshotted into the run")
	_check(DungeonManager.pending_expedition_multiplier("chest_spawn") == 1.0,
		"unrelated dungeon rewards remain normal")
	BoomManager.clear_expedition_boom()
	_check(DungeonManager.pending_expedition_multiplier("drop_rate") == 4.0,
		"planned run retains its authoritative Boom context")
	_check(BoomManager.force_expedition_boom("treasure_surge", "kingdom_hearts"),
		"treasure surge can target the unlocked expedition")
	DungeonManager.plan_expedition("kingdom_hearts", "sora")
	_check(DungeonManager.pending_expedition_multiplier("chest_spawn") == 2.0,
		"double chest spawning is snapshotted into the run")
	var saved := BoomManager.to_save().duplicate(true)
	BoomManager.clear_expedition_boom()
	BoomManager.from_save(saved)
	_check(BoomManager.active_expedition_boom_id == "treasure_surge",
		"Expedition Boom survives save/load")
	_check(BoomManager.expedition_world_id == "kingdom_hearts",
		"saved Expedition Boom retains its world")


func _test_order_access() -> void:
	var full_catalog := MarketManager.wholesale_catalog()
	var available := MarketManager.accessible_wholesale_catalog()
	_check(not available.is_empty(), "chapter one has orderable merchandise")
	_check(available.size() < full_catalog.size(),
		"later chapter goods are excluded from the chapter-one order pool")
	var customer := {
		"id": "chapter_safe_order_test",
		"archetype": "collector",
		"world": "kingdom_hearts",
	}
	for offer_index in range(100):
		var offer := CustomerGen.make_order_offer(customer, false, true)
		_check(not offer.is_empty(), "forced order %d can be generated" % offer_index)
		if not offer.is_empty():
			_check(MarketManager.is_item_accessible(String(offer.get("target", ""))),
				"order %d targets currently accessible merchandise" % offer_index)
	TimeManager.chapter = 2
	var chapter_two := MarketManager.accessible_wholesale_catalog()
	_check(chapter_two.size() > available.size(),
		"advancing a chapter expands the orderable catalog")
