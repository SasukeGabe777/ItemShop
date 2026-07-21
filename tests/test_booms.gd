extends Node
## Focused Boom-system proof: data integrity, dramatic traffic, weighting,
## direct requests, bulk sales, save state, cooldown, and gate celebrations.

var failures: Array[String] = []


func _ready() -> void:
	_reset_all()
	_validate_definitions()
	_test_traffic_and_preferences()
	_reset_all()
	_test_bulk_sale_and_request()
	_reset_all()
	_test_save_and_completion()
	_reset_all()
	_test_new_world_celebration()
	if failures.is_empty():
		print("BOOM_TEST_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("BOOM_TEST_FAIL: " + message)


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
	StoryEventManager.reset()
	CustomerGen.rng.seed = 20260720
	BoomManager.rng.seed = 20260720


func _validate_definitions() -> void:
	_check(ContentDatabase.booms.size() >= 10, "starter selection contains at least ten Booms")
	var categories := {"weapon": true, "armor": true, "accessory": true, "consumable": true,
		"food": true, "material": true, "treasure": true, "key": true}
	var attributes := {"cozy": true, "intense": true, "retro": true, "modern": true}
	var tags: Dictionary = {}
	for item_id: String in ContentDatabase.items:
		for tag in ContentDatabase.get_item(item_id).get("tags", []):
			tags[String(tag)] = true
	for boom_id: String in ContentDatabase.booms:
		var boom: Dictionary = ContentDatabase.booms[boom_id]
		_check(float(boom.get("traffic_multiplier", 0.0)) >= 2.0, "%s has dramatic traffic" % boom_id)
		_check(float(boom.get("request_frequency", -1.0)) >= 0.0, "%s defines request frequency" % boom_id)
		for archetype: String in boom.get("customer_weights", {}):
			_check(ContentDatabase.archetypes.has(archetype), "%s references real archetype %s" % [boom_id, archetype])
		for category in boom.get("preferred_categories", []):
			_check(categories.has(String(category)), "%s references real category %s" % [boom_id, category])
		for tag in boom.get("preferred_tags", []):
			_check(tags.has(String(tag)), "%s references real tag %s" % [boom_id, tag])
		for world in boom.get("preferred_worlds", []):
			_check(ContentDatabase.worlds.has(String(world)), "%s references real world %s" % [boom_id, world])
		for attr in boom.get("preferred_shop_attributes", []):
			_check(attributes.has(String(attr)), "%s references real shop attribute %s" % [boom_id, attr])


func _test_traffic_and_preferences() -> void:
	CustomerGen.rng.seed = 11
	var normal_count := CustomerGen.generate_session_customers().size()
	_check(BoomManager.force_boom("kids_adventure_day"), "Kids' Adventure Day can be forced")
	CustomerGen.rng.seed = 11
	BoomManager.rng.seed = 11
	var crowd := CustomerGen.generate_session_customers()
	_check(crowd.size() >= normal_count * 2, "Boom traffic is at least twice normal (%d vs %d)" % [crowd.size(), normal_count])
	var kid_groups := 0
	for customer: Dictionary in crowd:
		_check(String(customer.get("boom_id", "")) == "kids_adventure_day", "generated crowd carries Boom context")
		if String(customer.get("archetype", "")) in ["child", "parent", "food_lover", "bargain_hunter"]:
			kid_groups += 1
	_check(kid_groups * 2 >= crowd.size(), "Kids' Adventure Day strongly weights fitting customer groups")
	_check(BoomManager.item_match_score("super_mushroom") > 0.0, "real Mario food matches Kids' Adventure Day")
	_check(BoomManager.item_match_score("substitute_plush") > 0.0, "real cute collectible matches Kids' Adventure Day")
	InventoryManager.add_item("buster_sword")
	InventoryManager.place_display(0, "buster_sword")
	var test_customer := {"id": "unprepared_kid", "name": "Junior Hero", "archetype": "child",
		"budget": 100000, "world": "", "named": false, "boom_id": BoomManager.active_boom_id, "purchase_qty": 1}
	CustomerGen.rng.seed = 19
	var rejected := 0
	for i in range(20):
		if CustomerGen.pick_interest(test_customer) == "":
			rejected += 1
	_check(rejected >= 12, "poorly prepared shop usually produces requests or disappointed departures")
	InventoryManager.take_display(0)
	InventoryManager.add_item("super_mushroom")
	InventoryManager.place_display(0, "super_mushroom")
	_check(CustomerGen.pick_interest(test_customer) == "super_mushroom", "matching displayed stock wins Boom customer interest")


func _test_bulk_sale_and_request() -> void:
	_check(BoomManager.force_boom("crossroads_food_festival"), "Food Festival can be forced")
	InventoryManager.add_item("ramen_bowl", 5)
	_check(InventoryManager.place_display(0, "ramen_bowl"), "real festival item can be displayed")
	var customer := {"id": "boom_food_test", "name": "Festival Guest", "archetype": "food_lover",
		"budget": 100000, "world": "", "named": false, "boom_id": BoomManager.active_boom_id, "purchase_qty": 3}
	var negotiation := Negotiation.start(customer, "ramen_bowl")
	_check(negotiation.quantity == 3, "bulk-friendly Boom customer requests three stocked goods")
	var before_gold := EconomyManager.gold
	var before_sales := int(GameState.stats.get("sales", 0))
	var outcome := negotiation.propose(negotiation.market_value)
	_check(String(outcome.get("result", "")) in [Negotiation.RESULT_ACCEPT, Negotiation.RESULT_PERFECT], "bulk offer is negotiable normally")
	negotiation.finalize_sale(outcome)
	_check(int(outcome.get("quantity", 0)) == 3, "sale outcome reports physical quantity")
	_check(InventoryManager.count("ramen_bowl") == 2, "bulk sale removes display copy plus two storage copies")
	_check(EconomyManager.gold == before_gold + int(outcome["price"]), "bulk sale banks the negotiated bundle total")
	_check(int(GameState.stats.get("sales", 0)) == before_sales + 3, "bulk sale counts all three physical items")
	_check(EconomyManager.day_sales.size() == 3, "sale summary records each physical item")

	InventoryManager.orders.clear()
	BoomManager.rng.seed = 7
	var order := CustomerGen.maybe_make_order(customer, true)
	_check(not order.is_empty(), "unstocked Boom customer makes a direct request")
	if not order.is_empty():
		var found_matching_item := false
		for item_id in ContentDatabase.live_items:
			if InventoryManager.order_matches(order, item_id) and BoomManager.item_match_score(item_id) > 0.0:
				found_matching_item = true
				break
		_check(found_matching_item, "direct request targets merchandise demanded by the Boom")


func _test_save_and_completion() -> void:
	BoomManager.force_boom("retro_game_night")
	var saved := SaveManager._collect().duplicate(true)
	BoomManager.clear_active()
	SaveManager._apply(saved)
	_check(BoomManager.active_boom_id == "retro_game_night", "active Boom survives save/load")
	_check(BoomManager.sessions_left == 1, "remaining session duration survives save/load")
	ShopSim.run_session(1.0)
	_check(not BoomManager.is_active(), "headless and live shop paths both consume a one-session Boom")
	_check(int(BoomManager.eligible_after_day.get("retro_game_night", 0)) > TimeManager.day, "completed Boom starts its cooldown")


func _test_new_world_celebration() -> void:
	EconomyManager.add_gold(100000)
	BridgeManager.collect_shard("kingdom_hearts")
	_check(BridgeManager.pay_repair("kingdom_hearts"), "test gate can be repaired")
	_check(BoomManager.active_boom_id == "new_world_celebration", "repair immediately schedules the celebration Boom")
	_check(BoomManager.active_world_id == "kingdom_hearts", "celebration targets the newly restored real world")
	_check(BoomManager.item_match_score("kh_potion") > 0.0, "celebration prefers merchandise from the restored world")
	_check("Kingdom Hearts" in BoomManager.announcement(), "celebration announcement names the restored world")
