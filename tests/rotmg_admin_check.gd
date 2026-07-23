extends Node
## Logic probe (headless-safe): trigger admin mode and assert the full unlock.

func _ready() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()

	DebugManager.enable_admin_mode()

	var fails: Array[String] = []
	if not DebugManager.admin_mode:
		fails.append("admin_mode flag not set")
	if EconomyManager.gold < 9_999_999:
		fails.append("gold too low: %d" % EconomyManager.gold)
	for h: String in ContentDatabase.heroes:
		if not (h in GameState.met_heroes):
			fails.append("hero not met: %s" % h)
	for w: String in BridgeManager.gates:
		if not BridgeManager.is_repaired(w):
			fails.append("gate not repaired: %s" % w)
	var acc := BridgeManager.accessible_worlds()
	for must: String in ["rotmg", "null_archive", "kingdom_hearts"]:
		if not (must in acc):
			fails.append("world not accessible: %s" % must)
	var have := 0
	for id: String in ContentDatabase.live_items:
		if InventoryManager.count(id) >= 10:
			have += 1
	if have < ContentDatabase.live_items.size():
		fails.append("items in bag: %d/%d" % [have, ContentDatabase.live_items.size()])

	print("ADMIN: gold=%d heroes=%d/%d gates=%d accessible=%d items=%d/%d chapter=%d" % [
		EconomyManager.gold, GameState.met_heroes.size(), ContentDatabase.heroes.size(),
		BridgeManager.gates.size(), acc.size(), have, ContentDatabase.live_items.size(),
		TimeManager.chapter])
	if fails.is_empty():
		print("ADMIN_CHECK_PASS")
	else:
		for f in fails:
			printerr("ADMIN_CHECK_FAIL: " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
