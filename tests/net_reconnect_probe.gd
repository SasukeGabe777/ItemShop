extends Node
## M5: reconnect. Host kicks the client's ENet peer to simulate a Wi-Fi drop;
## the client must auto-reconnect via its session token into the SAME seat
## (new peer id, same player_index).

const REPORT_PATH := "user://net_reconnect_client.json"

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
	_expect(Net.host_game("HostGabe") == OK, "host_game failed")

	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(exe,
		["--headless", "--path", proj, "res://tests/net_reconnect_client.tscn"])
	_expect(pid > 0, "could not spawn client instance")

	# A localhost drop+reconnect completes in ~20 ms — far too fast to observe
	# by polling. Record every (connected, peer_id) transition of seat 2 via
	# the roster signal instead.
	var transitions: Array = []
	PartyState.changed.connect(func() -> void:
		if not PartyState.players.has(2):
			return
		var seat: Dictionary = PartyState.player(2)
		var state: Array = [bool(seat.get("connected", false)), int(seat.get("peer_id", 0))]
		if transitions.is_empty() or transitions[-1] != state:
			transitions.append(state))

	var seated := await _wait_for(func() -> bool:
		return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
	_expect(seated, "client never seated")
	var peer_before := PartyState.peer_for(2)
	var token_before := String(PartyState.player(2).get("session_token", ""))

	# Simulated drop: sever the ENet peer from the host side.
	await get_tree().create_timer(0.5).timeout
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	enet.disconnect_peer(peer_before)

	# The client reconnects, lingers 5 s, then quits — wait for its report,
	# then judge the recorded transition sequence.
	var reported := await _wait_for(func() -> bool:
		return FileAccess.file_exists(REPORT_PATH), 60.0)
	_expect(reported, "client never wrote its report")
	var drop_at := _find_transition(transitions, 0, false, peer_before)
	_expect(drop_at >= 0, "kick never flagged seat 2 disconnected (%s)" % [transitions])
	if drop_at >= 0:
		var back_at := -1
		for i in range(drop_at + 1, transitions.size()):
			if bool(transitions[i][0]) and int(transitions[i][1]) != peer_before:
				back_at = i
				break
		_expect(back_at > drop_at,
			"no reconnect with a fresh peer id after the drop (%s)" % [transitions])
	_expect(String(PartyState.player(2).get("session_token", "")) == token_before,
		"session token changed across reconnect")
	_expect(PartyState.count() == 2, "reconnect consumed an extra seat (%d)" % PartyState.count())

	await get_tree().create_timer(0.5).timeout
	if reported:
		var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f = null
		var report: Dictionary = parsed if parsed is Dictionary else {}
		_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
		_expect(bool(report.get("lost_fired", false)), "client connection_lost never fired")
		_expect(bool(report.get("reconnected_fired", false)), "client reconnected never fired")
		_expect(int(report.get("index_before", 0)) == 2 and int(report.get("index_after", 0)) == 2,
			"client seat changed: %s -> %s" % [report.get("index_before"), report.get("index_after")])
		_expect(bool(report.get("token_same", false)), "client token changed")

	Net.leave()
	if failures.is_empty():
		print("NET_RECONNECT_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_RECONNECT_PROBE_FAIL: ", failure)
		get_tree().quit(1)


func _find_transition(transitions: Array, from: int, connected: bool, peer: int) -> int:
	for i in range(from, transitions.size()):
		if bool(transitions[i][0]) == connected and int(transitions[i][1]) == peer:
			return i
	return -1


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
