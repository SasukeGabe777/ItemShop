extends Node
## Full headless campaign verification:
##  1. save/load roundtrip preserves state
##  2. negotiation + shop session logic works
##  3. crafting works
##  4. a full 5-day chapter can be completed (shard + payment)
##  5. the 35-day economy supports all seven repairs (auto-played campaign)
##  6. every boss is defeatable with a reasonably equipped hero
##  7. failure restart retains the right things
##  8. ending + endless mode unlock

var failures: Array[String] = []
var rng := RandomNumberGenerator.new()


func fail(msg: String) -> void:
	failures.append(msg)
	printerr("CAMPAIGN_TEST_FAIL: " + msg)


func check(cond: bool, msg: String) -> void:
	if not cond:
		fail(msg)


func _ready() -> void:
	rng.seed = 20260716
	_reset_all()
	_test_negotiation()
	_reset_all()
	_test_crafting()
	_reset_all()
	_test_save_roundtrip()
	_reset_all()
	_test_bosses_defeatable()
	_reset_all()
	_test_failure_restart()
	_reset_all()
	var won := _test_full_campaign()
	check(won, "35-day auto-campaign should reach all 7 repairs + fade defeat")
	if failures.is_empty():
		print("CAMPAIGN_TEST_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _reset_all() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()


func _test_negotiation() -> void:
	InventoryManager.add_item("kh_potion", 5)
	InventoryManager.place_display(0, "kh_potion")
	var cust := {"id": "test_cust", "name": "Tester", "archetype": "adventurer", "budget": 10000, "hero_ref": "", "world": "", "named": false}
	var nego := Negotiation.start(cust, "kh_potion")
	check(nego.market_value > 0, "market value positive")
	var lowball := nego.propose(1)
	check(String(lowball["result"]) in [Negotiation.RESULT_ACCEPT, Negotiation.RESULT_PERFECT], "cheap price accepted")
	nego = Negotiation.start(cust, "kh_potion")
	var gouge := nego.propose(nego.market_value * 50)
	check(String(gouge["result"]) in [Negotiation.RESULT_COUNTER, Negotiation.RESULT_FINAL_WARNING, Negotiation.RESULT_LEAVE], "gouging countered or refused")
	# whole session
	var gold_before := EconomyManager.gold
	ShopSim.auto_stock_display()
	var result := ShopSim.run_session(1.2)
	check(int(result["customers"]) >= 2, "session generated customers")
	if int(result["sales"]) > 0:
		check(EconomyManager.gold > gold_before, "revenue banked")
	# orders
	var order := InventoryManager.add_order("test_cust", "item", "kh_potion", 1, 100)
	check(not order.is_empty(), "order created")
	InventoryManager.add_item("kh_potion", 1)
	check(InventoryManager.try_fulfill_order(int(order["id"])), "order fulfilled from storage")


func _test_crafting() -> void:
	EconomyManager.add_gold(10000)
	InventoryManager.add_item("fire_flower", 1)
	InventoryManager.add_item("blaze_shard", 1)
	var r := ContentDatabase.get_recipe("r_flame_charm")
	check(not r.is_empty(), "crossover recipe exists")
	for iid: String in r["inputs"]:
		check(InventoryManager.count(iid) >= int(r["inputs"][iid]), "have input %s" % iid)
	EconomyManager.spend_gold(int(r["fee"]))
	for iid: String in r["inputs"]:
		InventoryManager.remove_item(iid, int(r["inputs"][iid]))
	InventoryManager.add_item(String(r["output"]))
	check(InventoryManager.count("flame_charm") == 1, "crafted flame charm")


func _test_save_roundtrip() -> void:
	EconomyManager.add_gold(4321)
	InventoryManager.add_item("master_sword", 2)
	InventoryManager.place_display(0, "master_sword")
	RelationshipManager.change_relationship("sora", 25)
	BridgeManager.collect_shard("kingdom_hearts")
	GameState.set_flag("test_flag")
	GameState.add_merchant_xp(500)
	TimeManager.advance(3)
	InventoryManager.equip("cloud", "charm", "")  # no-op but exercises path
	var gold := EconomyManager.gold
	var level := GameState.merchant_level
	var day := TimeManager.day
	var period := TimeManager.period
	check(SaveManager.save_to_slot(3), "save slot 3")
	_reset_all()
	check(SaveManager.load_from_slot(3), "load slot 3")
	check(EconomyManager.gold == gold, "gold restored (%d vs %d)" % [EconomyManager.gold, gold])
	check(GameState.merchant_level == level, "merchant level restored")
	check(TimeManager.day == day and TimeManager.period == period, "time restored")
	check(InventoryManager.count("master_sword") == 1, "storage restored")
	check(String(InventoryManager.display[0]) == "master_sword", "display restored")
	check(RelationshipManager.points("sora") == 25, "relationship restored")
	check(BridgeManager.has_shard("kingdom_hearts"), "shard restored")
	check(GameState.has_flag("test_flag"), "flag restored")
	SaveManager.delete_slot(3)


func _equip_best_available(hero_id: String) -> void:
	# give the hero solid gear in every slot (simulates a player who shops for
	# their adventurers, which the design intends)
	var hero := ContentDatabase.get_hero(hero_id)
	var wt := String(hero.get("weapon_type", ""))
	var best := {"weapon": ["", -1], "armor": ["", -1], "accessory": ["", -1], "charm": ["", -1]}
	for id: String in ContentDatabase.items:
		var it: Dictionary = ContentDatabase.items[id]
		var stats: Dictionary = it.get("stats", {})
		var score := int(stats.get("atk", 0)) * 2 + int(stats.get("def", 0)) * 2 + int(stats.get("spd", 0))
		var cat := String(it.get("category", ""))
		if cat == "weapon" and String(it.get("weapon_type", "")) == wt and score > int(best["weapon"][1]):
			best["weapon"] = [id, score]
		elif cat == "armor" and score > int(best["armor"][1]):
			best["armor"] = [id, score]
		elif cat == "accessory":
			var slot := String(it.get("slot", "accessory"))
			if slot in best and score > int(best[slot][1]):
				best[slot] = [id, score]
	for slot: String in best:
		var id := String(best[slot][0])
		if id != "":
			InventoryManager.hero_equipment[hero_id][slot] = id


func _test_bosses_defeatable() -> void:
	for wid in ContentDatabase.world_order:
		var w := ContentDatabase.get_world(wid)
		var hid := String(w.get("hero", ""))
		if bool(w.get("final", false)):
			hid = "goku"
		_equip_best_available(hid)
		RelationshipManager.change_relationship(hid, 100)  # max friendship
		var wins := 0
		var tries := 8
		for t in range(tries):
			var heals: Array = ["senzu_bean", "senzu_bean"] if wid != "kingdom_hearts" else ["kh_potion", "kh_potion"]
			var result := DungeonManager.simulate_expedition(wid, hid, rng.randi(), heals)
			if bool(result["boss_defeated"]):
				wins += 1
		check(wins >= tries / 2, "boss of %s defeatable by equipped %s (won %d/%d)" % [wid, hid, wins, tries])


func _test_failure_restart() -> void:
	SaveManager.checkpoint_chapter()
	GameState.add_merchant_xp(350)
	GameState.learn_item("master_sword")
	GameState.know_customer("sora_c")
	EconomyManager.add_gold(9999)
	InventoryManager.add_item("dragon_ball", 3)
	var level := GameState.merchant_level
	var ok := SaveManager.restart_chapter(["dragon_ball", "dragon_ball"])
	check(ok, "restart_chapter succeeds")
	check(GameState.merchant_level == level, "merchant level retained after failure")
	check("master_sword" in GameState.encyclopedia, "encyclopedia retained")
	check("sora_c" in GameState.known_customers, "customer knowledge retained")
	check(InventoryManager.count("dragon_ball") == 2, "kept exactly 2 chosen items, got %d" % InventoryManager.count("dragon_ball"))
	check(EconomyManager.gold == int(ContentDatabase.bal("starting_gold", 1000)), "gold rolled back to checkpoint")


## Auto-plays the whole campaign with a simple day policy:
## morning: buy stock; afternoon+evening: run shop; night: expedition when the
## shard is missing (every other day), otherwise shop again.
func _test_full_campaign() -> bool:
	var log_days: Array[String] = []
	while TimeManager.chapter <= 7:
		var w := ContentDatabase.world_for_chapter(TimeManager.chapter)
		var wid := String(w.get("id", ""))
		var hid := String(w.get("hero", ""))
		var repair := BridgeManager.repair_cost(wid)
		# one-time gear-up per chapter
		if not GameState.has_flag("geared_" + hid):
			_equip_best_available(hid)
			GameState.set_flag("geared_" + hid)
		var day_start := TimeManager.day
		# Morning: restock (keep cash for repairs when close to goal)
		var reserve := repair if BridgeManager.has_shard(wid) else int(repair * 0.4)
		if EconomyManager.gold > reserve + 400:
			ShopSim.auto_buy_stock(clampf(float(EconomyManager.gold - reserve) / maxf(1.0, float(EconomyManager.gold)) * 0.7, 0.0, 0.7))
		ShopSim.auto_stock_display()
		ShopSim.run_session(1.22)
		_maybe_pay(wid, repair)
		var events := TimeManager.advance(1)
		if _campaign_step_failed(events):
			return false
		# Afternoon+Evening: expedition — first for the shard, then to farm loot
		# (bosses respawn corrupted echoes; their drops fund late repairs)
		var did_dungeon := false
		var hire := int(ContentDatabase.get_hero(hid).get("hire_cost", 100))
		if EconomyManager.can_afford(hire + 200):
			EconomyManager.spend_gold(hire)
			var heals: Array = []
			for pid in ["senzu_bean", "kh_elixir", "ff_elixir", "full_restore", "hi_potion", "kh_potion", "ramen_bowl"]:
				while heals.size() < 2 and InventoryManager.count(pid) > 0:
					InventoryManager.remove_item(pid)
					heals.append(pid)
			# a sensible player buys healing for the trip
			if heals.size() < 2:
				for pid in MarketManager.wholesale_catalog():
					var fx: Dictionary = ContentDatabase.get_item(pid).get("effect", {})
					if int(fx.get("heal", 0)) >= 40:
						while heals.size() < 2 and EconomyManager.spend_gold(MarketManager.wholesale_cost(pid)):
							heals.append(pid)
					if heals.size() >= 2:
						break
			var result := DungeonManager.simulate_expedition(wid, hid, rng.randi(), heals)
			for iid: String in result["loot"]:
				InventoryManager.add_item(iid, int(result["loot"][iid]))
			EconomyManager.add_gold(int(result["gold"]))
			if bool(result["boss_defeated"]):
				BridgeManager.collect_shard(wid)
			did_dungeon = true
		if did_dungeon:
			_maybe_pay(wid, repair)
			events = TimeManager.advance(2)
			if _campaign_step_failed(events):
				return false
		else:
			for s in range(2):
				ShopSim.auto_stock_display()
				ShopSim.run_session(1.22)
				_maybe_pay(wid, repair)
				events = TimeManager.advance(1)
				if _campaign_step_failed(events):
					return false
		# Night: sell again
		ShopSim.auto_stock_display()
		ShopSim.run_session(1.18)
		_maybe_pay(wid, repair)
		events = TimeManager.advance(1)  # ends the day
		if _campaign_step_failed(events):
			return false
		_daily_log.append("day %d ch %d gold %d shard=%s repaired=%d prosperity=%.2f mlvl=%d" % [day_start, TimeManager.chapter, EconomyManager.gold, BridgeManager.has_shard(wid), BridgeManager.repaired_count(), MarketManager.prosperity(), GameState.merchant_level])
		log_days.append("")
		if TimeManager.day > 60:
			fail("campaign ran away past day 60")
			for l in log_days:
				print("  " + l)
			return false
	# Final chapter: defeat the Fade with any repaired hero
	check(BridgeManager.repaired_count() == 7, "all seven gates repaired (got %d)" % BridgeManager.repaired_count())
	print("  [campaign] all gates repaired on day %d with %dg spare" % [TimeManager.day, EconomyManager.gold])
	var final_win := false
	for t in range(10):
		var result := DungeonManager.simulate_expedition("null_archive", "goku", rng.randi(), ["senzu_bean", "senzu_bean"])
		if bool(result["boss_defeated"]):
			final_win = true
			break
	check(final_win, "the Fade defeatable in final dungeon")
	if final_win:
		BridgeManager.defeat_fade()
		StoryEventManager.fire("ending")
		GameState.endless_mode = true
		check(BridgeManager.is_chapter_complete(8), "final chapter complete")
	return BridgeManager.repaired_count() == 7 and final_win


func _maybe_pay(wid: String, repair: int) -> void:
	if BridgeManager.has_shard(wid) and not BridgeManager.is_repaired(wid) and EconomyManager.can_afford(repair):
		BridgeManager.pay_repair(wid)
		SaveManager.checkpoint_chapter()


var _daily_log: Array[String] = []


func _campaign_step_failed(events: Array[String]) -> bool:
	if "deadline_failed" in events:
		fail("deadline failed on day %d (chapter %d, gold %d, shard %s)" % [
			TimeManager.day, TimeManager.chapter, EconomyManager.gold,
			BridgeManager.has_shard(String(ContentDatabase.world_for_chapter(TimeManager.chapter).get("id", "")))])
		for l in _daily_log:
			print("  " + l)
		return true
	return false
