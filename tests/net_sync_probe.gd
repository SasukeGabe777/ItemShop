extends Node
## M2: host+orchestrator for the command-bus/state-sync test. Seeds known
## state, hosts, spawns net_sync_client.tscn in a second headless instance,
## and asserts that client-driven commands mutate host state, sync back to
## the client, and fail cleanly when invalid.

const REPORT_PATH := "user://net_sync_client.json"

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))

	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BoomManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()
	InventoryManager.add_item("kh_potion", 2)
	var gold_start := EconomyManager.gold
	var potions_start := InventoryManager.count("kh_potion")

	_expect(Net.host_game("HostGabe") == OK, "host_game failed")

	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(exe,
		["--headless", "--path", proj, "res://tests/net_sync_client.tscn"])
	_expect(pid > 0, "could not spawn client instance")

	var reported := await _wait_for(func() -> bool:
		return FileAccess.file_exists(REPORT_PATH), 30.0)
	_expect(reported, "client never wrote its report")
	await get_tree().create_timer(0.5).timeout

	if reported:
		var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f = null
		var report: Dictionary = parsed if parsed is Dictionary else {}
		_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
		_expect(bool(report.get("joined", false)), "client never joined")
		_expect(int(report.get("welcome_gold", -1)) == gold_start,
			"welcome snapshot gold mismatch (client %s vs host %d)"
				% [report.get("welcome_gold"), gold_start])
		_expect(int(report.get("welcome_potions", -1)) == potions_start,
			"welcome snapshot storage mismatch")
		_expect(int(report.get("gold_after_add", -1)) == gold_start + 120,
			"client gold after add wrong: %s" % report.get("gold_after_add"))
		_expect(bool(report.get("gold_changed_fired", false)),
			"client gold_changed did not fire on sync")
		_expect(bool(report.get("place_ok", false)), "place_display result not ok")
		_expect(String(report.get("display0_after", "")) == "kh_potion",
			"client display slot never synced")
		_expect(not bool(report.get("overdraft_ok", true)), "overdraft was accepted")
		_expect(String(report.get("overdraft_msg", "")) == "Not enough gold",
			"overdraft msg wrong: %s" % report.get("overdraft_msg"))
		_expect(bool(report.get("ready_seen", false)), "ready flag never round-tripped")

	# Host-side truth after the client's session.
	_expect(EconomyManager.gold == gold_start + 120,
		"host gold wrong after client commands: %d" % EconomyManager.gold)
	_expect(InventoryManager.display.size() > 0
		and String(InventoryManager.display[0]) == "kh_potion",
		"host display slot not set by client command")
	_expect(bool(PartyState.player(2).get("ready", false)), "host never saw seat 2 ready")

	Net.leave()
	if failures.is_empty():
		print("NET_SYNC_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_SYNC_PROBE_FAIL: ", failure)
		get_tree().quit(1)


func _wait_for(cond: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if bool(cond.call()):
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return bool(cond.call())


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
