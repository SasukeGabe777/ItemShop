extends Node
## M1: host+orchestrator for the connect/handshake/roster test. Hosts on
## 127.0.0.1, spawns a second headless instance running
## net_handshake_client.tscn, and asserts both sides' view of the roster,
## the leave flow, and the wrong-version rejection.

const REPORT_PATH := "user://net_probe_client.json"

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout

	var stale := ProjectSettings.globalize_path(REPORT_PATH)
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(stale)

	_expect(Net.host_game("HostGabe") == OK, "host_game failed")
	_expect(Net.is_online() and Net.is_host(), "host predicates wrong after host_game")
	_expect(Net.is_authority(), "host lost authority")
	_expect(PartyState.mode == PartyState.Mode.ONLINE, "host roster not in ONLINE mode")
	_expect(PartyState.count() == 1 and PartyState.local_index() == 1,
		"host seat is wrong")

	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(exe,
		["--headless", "--path", proj, "res://tests/net_handshake_client.tscn"])
	_expect(pid > 0, "could not spawn client instance")

	# Client joins -> seat 2 appears, named, with a live peer id.
	var seated := await _wait_for(func() -> bool: return PartyState.count() >= 2, 20.0)
	_expect(seated, "client never seated")
	if seated:
		_expect(PartyState.pname(2) == "ClientBro", "seat 2 name wrong: %s" % PartyState.pname(2))
		_expect(PartyState.peer_for(2) > 1, "seat 2 has no live peer id")
		_expect(bool(PartyState.player(2).get("connected", false)), "seat 2 not marked connected")
		_expect(String(PartyState.player(2).get("session_token", "")) != "",
			"seat 2 has no session token host-side")

	# Client leaves -> seat stays reserved but flags disconnected.
	var left := await _wait_for(func() -> bool:
		return PartyState.players.has(2) and not bool(PartyState.player(2).get("connected", true)), 20.0)
	_expect(left, "client leave never reflected in roster")

	# Wrong-version rejoin must be rejected without consuming a seat.
	var reported := await _wait_for(func() -> bool:
		return FileAccess.file_exists(REPORT_PATH), 20.0)
	_expect(reported, "client never wrote its report")
	await get_tree().create_timer(0.5).timeout
	if reported:
		var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f = null
		var report: Dictionary = parsed if parsed is Dictionary else {}
		_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
		_expect(bool(report.get("joined", false)), "client says it never joined")
		_expect(int(report.get("index", 0)) == 2, "client got index %s" % report.get("index"))
		_expect(int(report.get("roster_size", 0)) == 2, "client roster size %s" % report.get("roster_size"))
		_expect(bool(report.get("online_mode", false)), "client PartyState not ONLINE")
		_expect(String(report.get("reject_reason", "")).contains("Version mismatch"),
			"wrong-version join not rejected: %s" % report.get("reject_reason"))
	_expect(PartyState.count() == 2, "rejected client consumed a seat (%d)" % PartyState.count())

	Net.leave()
	_expect(not Net.is_online() and PartyState.mode == PartyState.Mode.SINGLE,
		"host leave did not restore offline state")

	if failures.is_empty():
		print("NET_HANDSHAKE_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_HANDSHAKE_PROBE_FAIL: ", failure)
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
