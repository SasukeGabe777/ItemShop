extends Node
## Headless contract for the catalog/progression hardening pass. These checks
## exercise the same runtime methods used by UI, customers, and rewards.

var failures: Array[String] = []


func _ready() -> void:
	AudioManager.set_muted(true)
	GameState.reset_campaign()
	InventoryManager.reset()
	EconomyManager.reset()
	RelationshipManager.reset()
	TimeManager.reset(3)
	MarketManager.active_events.clear()
	BoomManager.clear_active()
	_check_catalog_sources()
	_check_item_rarities()
	_check_chapter_three_stock()
	_check_trend_matches()
	_check_boom_matches()
	_check_orders()
	_check_sellback()
	_check_relationship_dialogue()
	await _check_consumable_feedback()
	if failures.is_empty():
		print("CORE_LOOP_HARDENING_PROBE_PASS")
	else:
		for message in failures:
			printerr("CORE_LOOP_HARDENING_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_catalog_sources() -> void:
	check(ContentDatabase.item_matches_world("oblivion_keyblade", "kingdom_hearts"),
		"Oblivion is not classified as Kingdom Hearts")
	check(ContentDatabase.item_matches_world("1up_mushroom", "mario"),
		"1UP Mushroom is not classified as Mario")
	check(ContentDatabase.item_has_source("oblivion_keyblade", "expedition_boss"),
		"Oblivion is not expedition-boss exclusive")
	check("oblivion_keyblade" not in MarketManager.wholesale_catalog(),
		"expedition-only Oblivion leaked into wholesale")
	check("kingdom_key" not in MarketManager.wholesale_catalog(),
		"expedition-only Kingdom Key leaked into wholesale")
	var darkside := ContentDatabase.get_enemy("darkside")
	var darkside_loot: Array[String] = []
	for entry: Array in darkside.get("loot", []):
		darkside_loot.append(String(entry[0]))
	check("oblivion_keyblade" in darkside_loot and "soul_eater" in darkside_loot,
		"Darkside does not award the rare KH relic pool")
	check("1up_mushroom" in ContentDatabase.expedition_chest_pool("mario"),
		"Mario expedition chests cannot roll the 1UP relic")


func _check_item_rarities() -> void:
	for item_id: String in ContentDatabase.live_items:
		check(ContentDatabase.item_rarity(item_id) in ContentDatabase.ITEM_RARITIES,
			"live item %s has no valid rarity" % item_id)
	check(ContentDatabase.item_rarity("kh_potion") == "Common",
		"basic Kingdom Hearts Potion is not Common")
	check(ContentDatabase.item_rarity("oblivion_keyblade") == "Legendary",
		"expedition-exclusive Oblivion is not Legendary")
	InventoryManager.add_item("kh_potion")
	InventoryManager.add_item("oblivion_keyblade")
	var by_rarity := InventoryManager.sorted_ids("rarity")
	check(by_rarity.find("oblivion_keyblade") < by_rarity.find("kh_potion"),
		"rarity sorting does not place Legendary items before Common items")


func _check_chapter_three_stock() -> void:
	var final_fantasy: Array[String] = []
	for item_id: String in MarketManager.accessible_wholesale_catalog():
		if ContentDatabase.item_matches_world(item_id, "final_fantasy"):
			final_fantasy.append(item_id)
	check(final_fantasy.size() >= 4,
		"Chapter 3 opens with fewer than four buyable Final Fantasy items")


func _check_trend_matches() -> void:
	for event_id: String in ContentDatabase.market_events:
		var event: Dictionary = ContentDatabase.market_events[event_id]
		if (event.get("mults", {}) as Dictionary).is_empty():
			continue
		TimeManager.chapter = int(event.get("min_chapter", 1))
		var affected := MarketManager.event_affected_items(event_id)
		check(not affected.is_empty(),
			"market trend %s advertises no obtainable items" % event_id)


func _check_boom_matches() -> void:
	TimeManager.chapter = 3
	check(BoomManager.force_boom("new_world_celebration", "final_fantasy"),
		"could not force the Final Fantasy world Boom")
	var affected := BoomManager.affected_items()
	check(not affected.is_empty(), "Final Fantasy world Boom has no affected stock")
	for item_id: String in affected:
		check(ContentDatabase.item_matches_world(item_id, "final_fantasy"),
			"world Boom included non-Final-Fantasy item %s" % item_id)
	BoomManager.clear_active()


func _check_orders() -> void:
	TimeManager.chapter = 3
	InventoryManager.last_order_request_day = -1
	var customer := CustomerGen.runtime_named(
		ContentDatabase.get_named_customer("cloud_c"))
	for i in range(12):
		InventoryManager.last_order_request_day = -1
		var offer := CustomerGen.make_order_offer(customer, false, true)
		check(not offer.is_empty(), "forced accessible order produced no offer")
		if not offer.is_empty():
			var target := String(offer.get("target", ""))
			check(target in MarketManager.accessible_wholesale_catalog(),
				"order requested inaccessible item %s" % target)


func _check_sellback() -> void:
	var item_id := "kh_potion"
	var before_count := InventoryManager.count(item_id)
	InventoryManager.add_item(item_id, 2)
	var before_gold := EconomyManager.gold
	var expected := MarketManager.sellback_value(item_id)
	check(MarketManager.sell_back(item_id), "market rejected owned sellback item")
	check(EconomyManager.gold == before_gold + expected,
		"sellback did not credit the advertised value")
	check(InventoryManager.count(item_id) == before_count + 1,
		"sellback removed the wrong inventory quantity")


func _check_relationship_dialogue() -> void:
	RelationshipManager.change_relationship("goofy_c", 22)
	var goofy := CustomerGen.runtime_named(
		ContentDatabase.get_named_customer("goofy_c"))
	goofy["budget"] = 1
	var opener := CustomerGen.conversation_opener(goofy, "oblivion_keyblade")
	check("friends" in opener and "my gal" in opener,
		"Goofy's friendship/short-purse dialogue did not unlock")
	var progress := RelationshipManager.progress_text("goofy_c")
	check("22 total" in progress and "2/10 to Lv.3" in progress,
		"bond progress does not distinguish lifetime points from next-level progress")


func _check_consumable_feedback() -> void:
	var hero := CombatHero.new()
	add_child(hero)
	hero.setup("mario", ["1up_mushroom"])
	hero._use_consumable()
	check(hero.revives_available == 1, "1UP did not preload a revive")
	check("Revive x1" in hero.active_status_text(),
		"loaded revive is invisible in active-status readout")
	hero.health.take_damage(hero.health.max_hp * 2, self)
	await get_tree().process_frame
	check(hero.health.hp > 0 and hero.revives_available == 0,
		"1UP did not revive the hero after lethal damage")
	hero.queue_free()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
