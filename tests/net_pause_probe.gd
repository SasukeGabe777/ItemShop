extends Node
## M5: pause semantics. Host pause pauses everyone (and lifts for everyone);
## a client's pause request is ignored — its world keeps running.

const REPORT_PATH := "user://net_pause_client.json"

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
	_expect(Net.host_game("HostGabe") == OK, "host_game failed")

	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(exe,
		["--headless", "--path", proj, "res://tests/net_pause_client.tscn"])
	_expect(pid > 0, "could not spawn client instance")

	var seated := await _wait_for(func() -> bool:
		return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
	_expect(seated, "client never seated")

	await get_tree().create_timer(0.5).timeout
	Net.request_tree_pause(true)
	_expect(get_tree().paused, "host pause did not pause the host")
	await get_tree().create_timer(2.0).timeout
	Net.request_tree_pause(false)
	_expect(not get_tree().paused, "host unpause did not lift")

	var reported := await _wait_for(func() -> bool:
		return FileAccess.file_exists(REPORT_PATH), 30.0)
	_expect(reported, "client never wrote its report")
	await get_tree().create_timer(0.5).timeout
	_expect(not get_tree().paused, "client pause request leaked to the host")
	if reported:
		var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f = null
		var report: Dictionary = parsed if parsed is Dictionary else {}
		_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
		_expect(bool(report.get("paused_with_host", false)), "client never paused with host")
		_expect(bool(report.get("unpaused_with_host", false)), "client never unpaused with host")
		_expect(bool(report.get("own_pause_ignored", false)), "client's own pause was not ignored")

	Net.leave()
	if failures.is_empty():
		print("NET_PAUSE_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_PAUSE_PROBE_FAIL: ", failure)
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
