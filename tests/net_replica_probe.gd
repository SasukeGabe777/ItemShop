extends Node2D
## M6: the entity-replication layer. Host registers a moving dummy entity;
## the client must spawn a puppet from its factory, track the position,
## receive events, honor the despawn, and drop stale-generation spawns. The
## client also streams its own player state, which must drive a puppet body
## on the host (channel-2 relay path).

const REPORT_PATH := "user://net_replica_client.json"

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
	_expect(Net.host_game("HostGabe") == OK, "host_game failed")

	var dummy := Node2D.new()
	dummy.global_position = Vector2(100, 100)
	add_child(dummy)
	var eid := Replica.host_register(dummy, "dummy", {"tag": "probe"})
	_expect(eid == 1, "first eid was %d" % eid)

	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(exe,
		["--headless", "--path", proj, "res://tests/net_replica_client.tscn"])
	_expect(pid > 0, "could not spawn client instance")

	var seated := await _wait_for(func() -> bool:
		return PartyState.players.has(2) and bool(PartyState.player(2).get("connected", false)), 20.0)
	_expect(seated, "client never seated")

	# Host-side puppet for the client's body: their streamed state must land.
	var pup := Node2D.new()
	add_child(pup)
	Replica.register_player_puppet(2, pup)

	# Walk the dummy to (300, 200) over ~2 s.
	for step in range(20):
		dummy.global_position = Vector2(100, 100).lerp(Vector2(300, 200), (step + 1) / 20.0)
		await get_tree().create_timer(0.1).timeout
	Replica.host_event(eid, "wave", {"n": 7})

	# A stale-generation spawn must be ignored by the client.
	Replica._spawn.rpc(Replica.gen - 1, 999, "dummy", {"tag": "stale"})

	await get_tree().create_timer(2.0).timeout
	Replica.host_despawn(eid, "death", {"killer": 1})

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
		_expect(String(report.get("spawn_kind", "")) == "dummy", "spawn kind wrong")
		_expect(String(report.get("spawn_tag", "")) == "probe", "spawn args lost")
		var fp: Array = report.get("final_pos", [0, 0])
		var final_pos := Vector2(float(fp[0]), float(fp[1]))
		_expect(final_pos.distance_to(Vector2(300, 200)) < 12.0,
			"client tracked pos off target: %s" % final_pos)
		_expect(String(report.get("event_name", "")) == "wave"
			and int(report.get("event_n", 0)) == 7, "event lost or mangled")
		_expect(String(report.get("despawn_reason", "")) == "death", "despawn reason wrong")
		_expect(bool(report.get("entity_gone", false)), "puppet not freed on despawn")
		_expect(not bool(report.get("stale_spawned", true)), "stale-gen spawn was accepted")

	# The client streamed [111, 222] for its body the whole session.
	_expect(pup.global_position.distance_to(Vector2(111, 222)) < 8.0,
		"player puppet never converged: %s" % pup.global_position)

	Net.leave()
	if failures.is_empty():
		print("NET_REPLICA_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_REPLICA_PROBE_FAIL: ", failure)
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
