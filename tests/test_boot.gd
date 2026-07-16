extends Node
## Minimal boot check: autoloads parsed and content loaded.

func _ready() -> void:
	var failures: Array[String] = []
	if ContentDatabase.items.size() < 100:
		failures.append("expected >=100 items, got %d" % ContentDatabase.items.size())
	if ContentDatabase.heroes.size() != 7:
		failures.append("expected 7 heroes, got %d" % ContentDatabase.heroes.size())
	if ContentDatabase.worlds.size() != 8:
		failures.append("expected 8 worlds, got %d" % ContentDatabase.worlds.size())
	if ContentDatabase.enemies.size() < 30:
		failures.append("expected >=30 enemies, got %d" % ContentDatabase.enemies.size())
	if ContentDatabase.bosses.size() != 8:
		failures.append("expected 8 bosses, got %d" % ContentDatabase.bosses.size())
	if ContentDatabase.recipes.size() < 35:
		failures.append("expected >=35 recipes, got %d" % ContentDatabase.recipes.size())
	if not ContentDatabase.load_errors.is_empty():
		failures.append("load errors: %s" % str(ContentDatabase.load_errors))
	# referential integrity: every loot/recipe/market item exists
	for eid: String in ContentDatabase.enemies:
		for entry in ContentDatabase.enemies[eid].get("loot", []):
			if not ContentDatabase.items.has(String(entry[0])):
				failures.append("enemy %s drops unknown item %s" % [eid, entry[0]])
	for bid: String in ContentDatabase.bosses:
		for entry in ContentDatabase.bosses[bid].get("loot", []):
			if not ContentDatabase.items.has(String(entry[0])):
				failures.append("boss %s drops unknown item %s" % [bid, entry[0]])
	for rid: String in ContentDatabase.recipes:
		var r: Dictionary = ContentDatabase.recipes[rid]
		if not ContentDatabase.items.has(String(r.get("output", ""))):
			failures.append("recipe %s outputs unknown item %s" % [rid, r.get("output")])
		for iid: String in r.get("inputs", {}):
			if not ContentDatabase.items.has(iid):
				failures.append("recipe %s uses unknown item %s" % [rid, iid])
	for wid: String in ContentDatabase.worlds:
		var w: Dictionary = ContentDatabase.worlds[wid]
		for g in w.get("market_goods", []):
			if not ContentDatabase.items.has(String(g)):
				failures.append("world %s sells unknown item %s" % [wid, g])
		for e in w.get("enemies", []):
			if not ContentDatabase.enemies.has(String(e)):
				failures.append("world %s spawns unknown enemy %s" % [wid, e])
		if not bool(w.get("final", false)) and not ContentDatabase.heroes.has(String(w.get("hero", ""))):
			failures.append("world %s has unknown hero" % wid)
		if not ContentDatabase.bosses.has(String(w.get("boss", ""))):
			failures.append("world %s has unknown boss" % wid)
	for cid: String in ContentDatabase.named_customers:
		var c: Dictionary = ContentDatabase.named_customers[cid]
		if not ContentDatabase.archetypes.has(String(c.get("archetype", ""))):
			failures.append("customer %s has unknown archetype" % cid)

	if failures.is_empty():
		print("BOOT_TEST_PASS")
	else:
		for f_msg in failures:
			printerr("BOOT_TEST_FAIL: " + f_msg)
	get_tree().quit(0 if failures.is_empty() else 1)
