extends Node
## Client half of tests/net_sync_probe — run in a second headless instance.
## Joins, checks the welcome snapshot, drives the command bus (success,
## failure and roster-mutating commands) and records everything to
## user://net_sync_client.json.

const OUT_PATH := "user://net_sync_client.json"

var report: Dictionary = {
	"joined": false,
	"welcome_gold": -1,
	"welcome_potions": -1,
	"gold_after_add": -1,
	"gold_changed_fired": false,
	"place_ok": false,
	"display0_after": "",
	"overdraft_ok": true,
	"overdraft_msg": "",
	"ready_seen": false,
	"error": "",
}


func _ready() -> void:
	await get_tree().create_timer(0.4).timeout
	EconomyManager.gold_changed.connect(func(_g: int) -> void:
		report["gold_changed_fired"] = true)
	Net.join_failed.connect(func(reason: String) -> void:
		_finish("join failed: %s" % reason))
	var err := Net.join_game("127.0.0.1", "SyncBro")
	if err != OK:
		_finish("create_client returned %s" % error_string(err))
		return
	var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
	if not joined:
		_finish("no welcome within 10s")
		return
	report["joined"] = true
	report["welcome_gold"] = EconomyManager.gold
	report["welcome_potions"] = InventoryManager.count("kh_potion")
	report["gold_changed_fired"] = false  # only count post-welcome syncs
	var base_gold := EconomyManager.gold

	# 1. Mutating command lands on host and syncs back.
	Net.request("economy.add_gold", {"amount": 120})
	var synced := await _wait_for(func() -> bool:
		return EconomyManager.gold == base_gold + 120, 10.0)
	if not synced:
		_finish("add_gold never synced back (gold=%d)" % EconomyManager.gold)
		return
	report["gold_after_add"] = EconomyManager.gold

	# 2. Validated command: display placement.
	Net.request("inventory.place_display", {"slot": 0, "item_id": "kh_potion"},
		func(ok: bool, _data: Dictionary) -> void: report["place_ok"] = ok)
	var placed := await _wait_for(func() -> bool:
		return InventoryManager.display.size() > 0 \
			and String(InventoryManager.display[0]) == "kh_potion", 10.0)
	if not placed:
		_finish("place_display never synced back")
		return
	report["display0_after"] = String(InventoryManager.display[0])

	# 3. Failure path rides back through _cmd_result.
	var failed := [false]
	Net.request("economy.spend_gold", {"amount": 99999999},
		func(ok: bool, data: Dictionary) -> void:
			report["overdraft_ok"] = ok
			report["overdraft_msg"] = String(data.get("msg", ""))
			failed[0] = true)
	var answered := await _wait_for(func() -> bool: return failed[0], 10.0)
	if not answered:
		_finish("overdraft request got no result")
		return

	# 4. Roster-mutating command: ready flag round-trips via _roster.
	Net.request("lobby.set_ready", {"ready": true})
	var readied := await _wait_for(func() -> bool:
		return bool(PartyState.player(Net.my_index).get("ready", false)), 10.0)
	report["ready_seen"] = readied

	_finish("")


func _wait_for(cond: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if bool(cond.call()):
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return bool(cond.call())


func _finish(err: String) -> void:
	report["error"] = err
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report))
		f = null
	get_tree().quit(0)
